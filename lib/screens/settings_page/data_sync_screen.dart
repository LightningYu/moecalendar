import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/character_provider.dart';
import '../../services/data_sync_service.dart';

class DataSyncScreen extends StatefulWidget {
  const DataSyncScreen({super.key});

  @override
  State<DataSyncScreen> createState() => _DataSyncScreenState();
}

class _DataSyncScreenState extends State<DataSyncScreen> {
  final DataSyncService _syncService = DataSyncService();
  bool _isLoading = false;

  // ============ 导出 ============

  Future<void> _exportToFile() async {
    setState(() => _isLoading = true);
    try {
      final filePath = await _syncService.exportToFile();
      if (!mounted) return;
      // 使用系统分享
      await SharePlus.instance.share(ShareParams(files: [XFile(filePath)]));
    } catch (e) {
      if (!mounted) return;
      _showError('导出失败: $e');
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
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.single.path;
      if (filePath == null) return;

      final content = await _syncService.readFile(filePath);
      if (content == null) {
        if (mounted) _showError('无法读取文件');
        return;
      }

      await _processImport(content);
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

    if (parsed.characters.isEmpty) {
      _showError('数据中没有角色信息');
      return;
    }

    if (!mounted) return;

    // 让用户选择导入模式
    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入数据'),
        content: Text(
          '检测到 ${parsed.characters.length} 个角色。\n\n'
          '请选择导入方式：',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'merge'),
            child: const Text('合并（保留已有）'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'replace'),
            child: const Text('替换（覆盖全部）'),
          ),
        ],
      ),
    );

    if (mode == null || !mounted) return;

    // 替换模式二次确认
    if (mode == 'replace') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认替换'),
          content: const Text('替换模式将删除当前所有角色数据，不可撤销！\n确定要继续吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认替换'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }

    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<CharacterProvider>(context, listen: false);
      final result = await provider.importCharacters(
        parsed.characters,
        mode: mode,
      );

      if (!mounted) return;

      final msg = mode == 'replace'
          ? '替换完成：共 ${result.total} 个角色'
          : '合并完成：新增 ${result.added} 个，更新 ${result.updated} 个';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) _showError('导入失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                        leading: const Icon(Icons.file_download),
                        title: const Text('导出为文件'),
                        subtitle: const Text('保存 JSON 文件并分享到其他设备'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _exportToFile,
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
                            '导出数据仅包含角色信息（不含头像图片文件）。'
                            '导入后 Bangumi 角色的头像会自动重新下载。\n\n'
                            '合并模式：保留已有角色，仅添加新角色。\n'
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
