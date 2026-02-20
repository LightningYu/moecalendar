import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/character_provider.dart';
import '../../services/data_sync_service.dart';

class DataSyncScreen extends StatefulWidget {
  /// 如果是通过 intent-filter 打开的 JSON 文件内容，传入此参数自动进入导入流程
  final String? initialImportJson;

  const DataSyncScreen({super.key, this.initialImportJson});

  @override
  State<DataSyncScreen> createState() => _DataSyncScreenState();
}

class _DataSyncScreenState extends State<DataSyncScreen> {
  final DataSyncService _syncService = DataSyncService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialImportJson != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processImport(widget.initialImportJson!);
      });
    }
  }

  // ============ 导出 ============

  /// 导出 JSON 并让用户选择保存位置
  Future<void> _exportSaveLocal() async {
    setState(() => _isLoading = true);
    try {
      final export = await _syncService.exportToBytes();
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: '选择保存位置',
        fileName: export.fileName,
        bytes: export.bytes,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (!mounted) return;
      if (savedPath != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已保存到: $savedPath')));
      }
    } catch (e) {
      if (!mounted) return;
      _showError('保存失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 导出并分享到其他应用
  Future<void> _exportAndShare() async {
    setState(() => _isLoading = true);
    try {
      final tempPath = await _syncService.exportToTempFile();
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(files: [XFile(tempPath)]));
    } catch (e) {
      if (!mounted) return;
      _showError('分享失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToClipboard() async {
    setState(() => _isLoading = true);
    try {
      final json = await _syncService.exportToJson();
      await Clipboard.setData(ClipboardData(text: json));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('数据已复制到剪贴板')));
    } catch (e) {
      if (!mounted) return;
      _showError('导出失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============ 导入 ============

  Future<void> _importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '选择导入文件',
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) _showError('无法读取文件内容，请检查文件权限');
        return;
      }

      final content = utf8.decode(bytes);
      await _processImport(content);
    } on PlatformException catch (e) {
      if (mounted) {
        if (e.code == 'read_external_storage_denied') {
          _showError('缺少存储权限，请在系统设置中授予应用存储权限后重试');
        } else {
          _showError('文件访问失败: ${e.message}');
        }
      }
    } catch (e) {
      if (mounted) _showError('导入失败: $e');
    }
  }

  Future<void> _importFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text == null || data!.text!.isEmpty) {
        if (mounted) _showError('剪贴板为空');
        return;
      }

      await _processImport(data.text!);
    } catch (e) {
      if (mounted) _showError('导入失败: $e');
    }
  }

  Future<void> _processImport(String jsonStr) async {
    final parsed = _syncService.parseJson(jsonStr);
    if (parsed == null) {
      _showError('数据格式无效，请确认是萌历导出的 JSON 文件');
      return;
    }

    if (parsed.isEmpty) {
      _showError('数据中没有角色信息');
      return;
    }

    if (!mounted) return;

    // 显示预览对话框
    final confirmed = await _showImportPreview(parsed);
    if (confirmed == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<CharacterProvider>(context, listen: false);
      final result = await provider.importCharacters(
        parsed.allFullCharacters,
        mode: confirmed,
        bangumiIdsOnly: parsed.bangumiIds,
      );

      if (!mounted) return;

      final parts = <String>[];
      if (confirmed == 'replace') {
        parts.add('替换完成：共 ${result.total} 个角色');
      } else {
        if (result.added > 0) parts.add('新增 ${result.added} 个');
        if (result.updated > 0) parts.add('更新 ${result.updated} 个');
        if (parts.isEmpty) parts.add('无新数据');
      }
      if (result.taskSubmitted > 0) {
        parts.add('${result.taskSubmitted} 个 Bangumi 角色将在下载池中处理');
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parts.join('，'))));
    } catch (e) {
      if (mounted) _showError('导入失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 显示导入预览对话框
  ///
  /// 返回 'merge'、'replace' 或 null（取消）
  Future<String?> _showImportPreview(ImportParseResult parsed) {
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        // 预览最多显示 5 个条目
        const previewLimit = 5;

        return AlertDialog(
          title: const Text('导入预览'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 统计信息
                  Text(
                    '检测到 ${parsed.totalCount} 个角色',
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (parsed.manualCharacters.isNotEmpty)
                    Text('  手动角色: ${parsed.manualCharacters.length} 个'),
                  if (parsed.fullBangumiCharacters.isNotEmpty)
                    Text(
                      '  Bangumi 角色(完整): ${parsed.fullBangumiCharacters.length} 个',
                    ),
                  if (parsed.bangumiIds.isNotEmpty)
                    Text('  Bangumi 角色(仅ID): ${parsed.bangumiIds.length} 个'),

                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),

                  // 手动角色预览
                  if (parsed.manualCharacters.isNotEmpty) ...[
                    Text(
                      '手动角色',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...parsed.manualCharacters
                        .take(previewLimit)
                        .map(
                          (c) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '• ${c.name} (${c.birthMonth}月${c.birthDay}日)',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ),
                    if (parsed.manualCharacters.length > previewLimit)
                      Text(
                        '  ...还有 ${parsed.manualCharacters.length - previewLimit} 个',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],

                  // Bangumi 角色预览
                  if (parsed.fullBangumiCharacters.isNotEmpty) ...[
                    Text(
                      'Bangumi 角色',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...parsed.fullBangumiCharacters
                        .take(previewLimit)
                        .map(
                          (c) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '• ${c.name} (${c.birthMonth}月${c.birthDay}日)',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ),
                    if (parsed.fullBangumiCharacters.length > previewLimit)
                      Text(
                        '  ...还有 ${parsed.fullBangumiCharacters.length - previewLimit} 个',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],

                  // bangumiId 列表预览
                  if (parsed.bangumiIds.isNotEmpty) ...[
                    Text(
                      'Bangumi 角色 (需下载详情)',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...parsed.bangumiIds
                        .take(previewLimit)
                        .map(
                          (id) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '• Bangumi #$id',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ),
                    if (parsed.bangumiIds.length > previewLimit)
                      Text(
                        '  ...还有 ${parsed.bangumiIds.length - previewLimit} 个',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            OutlinedButton(
              onPressed: () async {
                // 替换模式二次确认
                final confirm = await showDialog<bool>(
                  context: ctx,
                  builder: (ctx2) => AlertDialog(
                    title: const Text('确认替换'),
                    content: const Text('替换模式将删除当前所有角色数据，不可撤销！\n确定要继续吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx2, false),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(ctx2).colorScheme.error,
                        ),
                        onPressed: () => Navigator.pop(ctx2, true),
                        child: const Text('确认替换'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && ctx.mounted) {
                  Navigator.pop(ctx, 'replace');
                }
              },
              child: const Text('替换'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'merge'),
              child: const Text('合并（保留已有）'),
            ),
          ],
        );
      },
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  // ============ UI ============

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<CharacterProvider>(context);
    final charCount = provider.characters.length;

    return Scaffold(
      appBar: AppBar(title: const Text('数据管理')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 数据概览卡
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.storage,
                          size: 40,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('当前数据', style: theme.textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                '共 $charCount 个角色',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.hintColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 导出区域
                Text(
                  '导出数据',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.save),
                        title: const Text('保存 JSON 到本地'),
                        subtitle: const Text('将备份文件保存到应用文档目录'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _exportSaveLocal,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.share),
                        title: const Text('导出并分享'),
                        subtitle: const Text('生成 JSON 文件并分享到其他应用或设备'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _exportAndShare,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.copy),
                        title: const Text('复制到剪贴板'),
                        subtitle: const Text('复制 JSON 文本，可直接粘贴传输'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _exportToClipboard,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 导入区域
                Text(
                  '导入数据',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.file_upload),
                        title: const Text('从文件导入'),
                        subtitle: const Text('选择之前导出的 JSON 备份文件'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _importFromFile,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.paste),
                        title: const Text('从剪贴板导入'),
                        subtitle: const Text('粘贴从其他设备复制的 JSON 文本'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _importFromClipboard,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 提示信息
                Card(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '导出时 Bangumi 角色仅保存 ID（减小文件体积），'
                            '导入后会自动在下载池中获取详情和头像。\n\n'
                            '合并模式：保留已有角色，仅添加新角色（同名同日期自动去重）。\n'
                            '替换模式：删除当前所有数据并用导入数据替换。',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
