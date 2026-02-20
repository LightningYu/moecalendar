import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/character_model.dart';
import '../../providers/character_provider.dart';
import '../../bangumi/bangumi.dart';
import '../../services/calendar_service.dart';
import '../../widgets/name_avatar_widget.dart';

/// 统一的角色详情页
///
/// 支持两种模式：
/// 1. 本地模式：传入 [Character]，显示已添加的角色，支持删除和刷新
/// 2. 在线模式：传入 [BangumiCharacterDto]，显示在线搜索的角色，支持添加
class CharacterDetailScreen extends StatefulWidget {
  /// 本地已添加的角色（二选一）
  final Character? character;

  /// 在线 Bangumi 角色数据（二选一）
  final BangumiCharacterDto? bangumiDto;

  const CharacterDetailScreen({super.key, this.character, this.bangumiDto})
    : assert(
        character != null || bangumiDto != null,
        '必须提供 character 或 bangumiDto',
      );

  /// 从本地角色创建
  const CharacterDetailScreen.fromLocal({
    super.key,
    required Character this.character,
  }) : bangumiDto = null;

  /// 从在线 Bangumi 数据创建
  const CharacterDetailScreen.fromBangumi({
    super.key,
    required BangumiCharacterDto this.bangumiDto,
  }) : character = null;

  @override
  State<CharacterDetailScreen> createState() => _CharacterDetailScreenState();
}

class _CharacterDetailScreenState extends State<CharacterDetailScreen> {
  final BangumiService _bangumiService = BangumiService();

  // 状态
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isAdding = false;
  bool _showRawData = false;

  // 数据
  late Character? _localCharacter;
  BangumiCharacterDto? _onlineDto;

  /// 是否为本地模式（已添加的角色）
  bool get isLocalMode => widget.character != null;

  /// 是否为 Bangumi 角色
  bool get isBangumi =>
      (isLocalMode && _localCharacter is BangumiCharacter) ||
      (!isLocalMode && _onlineDto != null);

  /// 是否为自己
  bool get isSelf =>
      isLocalMode &&
      _localCharacter is ManualCharacter &&
      (_localCharacter as ManualCharacter).isSelf;

  /// 获取显示名称
  String get displayName {
    if (isSelf) return '你';
    if (isLocalMode) return _localCharacter!.name;
    return _onlineDto?.displayName ?? '';
  }

  /// 获取副标题（原名）
  String? get subName {
    if (!isLocalMode && _onlineDto != null) {
      return _onlineDto!.subName;
    }
    return null;
  }

  /// 获取 Bangumi ID
  int? get bangumiId {
    if (isLocalMode && _localCharacter is BangumiCharacter) {
      return (_localCharacter as BangumiCharacter).bangumiId;
    }
    return _onlineDto?.id;
  }

  /// 获取原始数据
  Map<String, dynamic> get originalData {
    if (isLocalMode && _localCharacter is BangumiCharacter) {
      return (_localCharacter as BangumiCharacter).originalData;
    }
    return _onlineDto?.originalData ?? {};
  }

  /// 是否有生日信息
  bool get hasBirthday {
    if (isLocalMode) return true; // 本地角色必然有生日
    return _onlineDto?.hasBirthday ?? false;
  }

  /// 获取生日文本
  String get birthdayText {
    if (isLocalMode) {
      final c = _localCharacter!;
      if (c.birthYear != null) {
        return '${c.birthYear}年${c.birthMonth}月${c.birthDay}日';
      }
      return '${c.birthMonth}月${c.birthDay}日';
    }
    return _onlineDto?.birthdayText ?? '';
  }

  @override
  void initState() {
    super.initState();
    _localCharacter = widget.character;
    _onlineDto = widget.bangumiDto;

    // 如果是在线模式且数据不完整，加载详情
    if (!isLocalMode && _onlineDto != null) {
      _loadOnlineDetail();
    }
  }

  // 加载在线详情（仅在线模式）
  Future<void> _loadOnlineDetail() async {
    if (_onlineDto == null) return;

    setState(() => _isLoading = true);

    try {
      final detail = await _bangumiService.getCharacterDetail(_onlineDto!.id);
      if (mounted && detail != null) {
        setState(() => _onlineDto = detail);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 刷新本地 Bangumi 角色数据
  Future<void> _refreshLocalCharacter() async {
    if (!isLocalMode || _localCharacter is! BangumiCharacter) return;

    final bangumiChar = _localCharacter as BangumiCharacter;
    setState(() => _isRefreshing = true);

    try {
      final provider = Provider.of<CharacterProvider>(context, listen: false);
      final updated = await provider.refreshBangumiCharacter(bangumiChar);

      if (updated == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('获取角色数据失败')));
        }
        return;
      }

      if (mounted) {
        setState(() => _localCharacter = updated);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('角色数据已更新，图片将在后台下载')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('刷新失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  /// 添加在线角色到本地
  Future<void> _addCharacter() async {
    final dto = _onlineDto;
    if (dto == null || !dto.hasBirthday) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该角色无生日信息，无法添加')));
      return;
    }

    setState(() => _isAdding = true);

    try {
      final provider = Provider.of<CharacterProvider>(context, listen: false);
      final newChar = await provider.addBangumiCharacterFromDto(dto);

      if (newChar != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已添加 ${dto.displayName}，图片将在后台下载')),
        );
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  /// 删除本地角色
  Future<void> _deleteCharacter() async {
    if (!isLocalMode || isSelf) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 $displayName 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '删除',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await Provider.of<CharacterProvider>(
        context,
        listen: false,
      ).deleteCharacter(_localCharacter!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _openBangumiPage() async {
    final id = bangumiId;
    if (id == null) return;
    final url = Uri.parse('https://bangumi.tv/character/$id');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// 添加生日到系统日历
  Future<void> _addToCalendar() async {
    if (!isLocalMode || _localCharacter == null) return;

    final success = await CalendarService.instance.addBirthdayToCalendar(
      _localCharacter!,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '已打开日历应用' : '无法打开日历'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  ImageProvider? _getImageProvider(String? urlOrPath) {
    if (urlOrPath == null) return null;
    if (urlOrPath.startsWith('http')) return NetworkImage(urlOrPath);
    return FileImage(File(urlOrPath));
  }

  String? _getDetailAvatarUrl() {
    if (isLocalMode && _localCharacter is BangumiCharacter) {
      final bc = _localCharacter as BangumiCharacter;
      return bc.detailAvatar ?? _extractImageFromData('large');
    }
    if (!isLocalMode && _onlineDto != null) {
      return _onlineDto!.detailAvatarUrl;
    }
    if (isLocalMode) {
      return _localCharacter?.avatarPath;
    }
    return null;
  }

  String? _extractImageFromData(String size) {
    final images = originalData['images'];
    if (images is Map<String, dynamic>) {
      return images[size] as String? ??
          images['common'] as String? ??
          images['medium'] as String?;
    }
    return null;
  }

  // ============ UI 构建 ============

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
        actions: [
          // 添加到日历按钮 (仅本地模式)
          if (isLocalMode && Platform.isAndroid)
            IconButton(
              icon: const Icon(Icons.calendar_month),
              tooltip: '添加到日历',
              onPressed: _addToCalendar,
            ),
          if (isBangumi)
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              tooltip: '在 Bangumi 中查看',
              onPressed: _openBangumiPage,
            ),
          if (isLocalMode && !isSelf)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteCharacter,
            ),
        ],
      ),
      floatingActionButton: !isLocalMode && hasBirthday
          ? FloatingActionButton.extended(
              onPressed: _isAdding ? null : _addCharacter,
              icon: _isAdding
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(_isAdding ? '添加中...' : '加入生日'),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeroImage(theme),
                  _buildNameSection(theme),
                  if (isBangumi) _buildTagsSection(theme),
                  _buildBirthdayCard(theme),
                  _buildBasicInfoCard(theme),
                  if (isBangumi) ...[
                    _buildSummaryCard(theme),
                    _buildInfoboxCard(theme),
                    if (originalData['stat'] != null) _buildStatCard(theme),
                    if (isLocalMode) _buildRefreshCard(theme),
                    _buildRawDataCard(theme),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  Widget _buildHeroImage(ThemeData theme) {
    final imageUrl = _getDetailAvatarUrl();
    final provider = _getImageProvider(imageUrl);

    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      color: theme.colorScheme.surfaceContainerHighest,
      child: provider != null
          ? Image(
              image: provider,
              fit: BoxFit.contain,
              width: double.infinity,
              errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
            )
          : _buildPlaceholder(theme),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return SizedBox(
      height: 200,
      child: Center(
        child: NameAvatarWidget(name: displayName, size: 120, isSelf: isSelf),
      ),
    );
  }

  Widget _buildNameSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subName != null) ...[
            const SizedBox(height: 4),
            Text(
              subName!,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTagsSection(ThemeData theme) {
    final data = originalData;
    final gender = data['gender'] as String?;
    final bloodType = data['blood_type'];

    String? genderText;
    if (gender == 'female') {
      genderText = '女';
    } else if (gender == 'male') {
      genderText = '男';
    } else if (gender != null) {
      genderText = gender;
    }

    String? bloodText;
    if (bloodType != null) {
      switch (bloodType) {
        case 1:
          bloodText = 'A型';
          break;
        case 2:
          bloodText = 'B型';
          break;
        case 3:
          bloodText = 'AB型';
          break;
        case 4:
          bloodText = 'O型';
          break;
        default:
          bloodText = '$bloodType型';
      }
    }

    final chips = <Widget>[];
    if (genderText != null) {
      chips.add(
        Chip(
          avatar: Icon(
            gender == 'female' ? Icons.female : Icons.male,
            size: 18,
          ),
          label: Text(genderText),
          visualDensity: VisualDensity.compact,
        ),
      );
    }
    if (bloodText != null) {
      chips.add(
        Chip(
          avatar: const Icon(Icons.water_drop_outlined, size: 18),
          label: Text(bloodText),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }

  Widget _buildBirthdayCard(ThemeData theme) {
    if (!hasBirthday) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.cake, color: theme.colorScheme.onPrimaryContainer),
        ),
        title: const Text('生日'),
        subtitle: Text(birthdayText, style: theme.textTheme.titleMedium),
      ),
    );
  }

  Widget _buildBasicInfoCard(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('基本信息', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _buildInfoRow(theme, '来源', isBangumi ? 'Bangumi' : '手动添加'),
            if (bangumiId != null)
              _buildInfoRow(theme, 'Bangumi ID', '$bangumiId'),
            if (isLocalMode) _buildInfoRow(theme, '状态', '已添加'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    final summary = originalData['summary'] as String?;
    if (summary == null || summary.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('简介', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SelectableText(
              summary,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoboxCard(ThemeData theme) {
    final infobox = originalData['infobox'];
    if (infobox == null || infobox is! List || infobox.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('详细信息', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ...infobox.map((item) {
              if (item is! Map || item['key'] == null) {
                return const SizedBox.shrink();
              }
              final key = item['key'].toString();
              final value = _formatInfoboxValue(item['value']);
              if (value.isEmpty) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      key,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(value, style: theme.textTheme.bodyMedium),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatInfoboxValue(dynamic value) {
    if (value is String) return value;
    if (value is List) {
      return value
          .map((e) {
            if (e is Map) {
              final k = e['k'] ?? '';
              final v = e['v'] ?? '';
              return k.toString().isNotEmpty ? '$k: $v' : v.toString();
            }
            return e.toString();
          })
          .join('\n');
    }
    return value?.toString() ?? '';
  }

  Widget _buildStatCard(ThemeData theme) {
    final stat = originalData['stat'] as Map<String, dynamic>?;
    if (stat == null) return const SizedBox.shrink();

    final comments = stat['comments'] ?? 0;
    final collects = stat['collects'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('统计', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    theme,
                    Icons.comment_outlined,
                    '讨论',
                    '$comments',
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    theme,
                    Icons.favorite_outline,
                    '收藏',
                    '$collects',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: theme.hintColor),
        const SizedBox(width: 8),
        Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRefreshCard(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('数据管理', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _isRefreshing ? null : _refreshLocalCharacter,
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(_isRefreshing ? '刷新中...' : '从 Bangumi 刷新数据'),
            ),
            const SizedBox(height: 8),
            Text(
              '重新从 Bangumi API 获取最新的角色信息和图片',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRawDataCard(ThemeData theme) {
    if (originalData.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('原始数据', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () => setState(() => _showRawData = !_showRawData),
              icon: Icon(_showRawData ? Icons.expand_less : Icons.data_object),
              label: Text(_showRawData ? '收起' : '查看原始 JSON'),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _showRawData
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  const JsonEncoder.withIndent('  ').convert(originalData),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
