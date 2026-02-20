import 'package:flutter/material.dart';
import '../bangumi/bangumi.dart';
import '../config/design_constants.dart';

/// 全局缓存：角色ID -> 完整数据
/// 避免同一角色重复请求
final Map<int, BangumiCharacterDto> _characterCache = {};

/// 统一的 Bangumi 角色列表项组件(本地/网络)
/// 会自动获取角色详情以显示生日信息
class BangumiCharacterListItem extends StatefulWidget {
  final BangumiCharacterDto character;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool?>? onCheckChanged;

  const BangumiCharacterListItem({
    super.key,
    required this.character,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onTap,
    this.onLongPress,
    this.onCheckChanged,
  });

  @override
  State<BangumiCharacterListItem> createState() =>
      _BangumiCharacterListItemState();
}

class _BangumiCharacterListItemState extends State<BangumiCharacterListItem> {
  final BangumiService _bangumiService = BangumiService();
  BangumiCharacterDto? _fullCharacter;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDetailIfNeeded();
  }

  @override
  void didUpdateWidget(BangumiCharacterListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character.id != widget.character.id) {
      _fullCharacter = null;
      _loadDetailIfNeeded();
    }
  }

  Future<void> _loadDetailIfNeeded() async {
    final character = widget.character;

    // 如果已经有生日数据，不需要获取
    if (character.hasBirthday) {
      return;
    }

    // 检查缓存
    if (_characterCache.containsKey(character.id)) {
      if (mounted) {
        setState(() {
          _fullCharacter = _characterCache[character.id];
        });
      }
      return;
    }

    // 获取详情
    if (_isLoading) return;
    _isLoading = true;

    try {
      final detail = await _bangumiService.getCharacterDetail(character.id);
      if (detail != null) {
        final mergedDetail = detail.roleName != null
            ? detail
            : detail.copyWith(roleName: character.roleName);
        _characterCache[character.id] = mergedDetail;
        if (mounted) {
          setState(() {
            _fullCharacter = mergedDetail;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load character detail: $e');
    } finally {
      _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 优先使用完整数据，否则使用传入的数据
    final character = _fullCharacter ?? widget.character;

    // 列表使用 listAvatarUrl (grid 尺寸)
    final avatarUrl = character.listAvatarUrl;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: DesignConstants.cardMarginH,
        vertical: DesignConstants.cardMarginV,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.isSelectionMode
            ? () => widget.onCheckChanged?.call(!widget.isSelected)
            : widget.onTap,
        onLongPress: widget.onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(DesignConstants.cardPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 多选模式下显示复选框
              if (widget.isSelectionMode) ...[
                Checkbox(
                  value: widget.isSelected,
                  onChanged: widget.onCheckChanged,
                ),
                const SizedBox(width: DesignConstants.spacingSm),
              ],
              // 头像
              ClipRRect(
                borderRadius: BorderRadius.circular(DesignConstants.radiusMd),
                child: Container(
                  width: DesignConstants.avatarSizeMd,
                  height: DesignConstants.avatarSizeMd,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: avatarUrl != null
                      ? Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.person_outline,
                            size: 28,
                            color: theme.hintColor,
                          ),
                        )
                      : Icon(
                          Icons.person_outline,
                          size: 28,
                          color: theme.hintColor,
                        ),
                ),
              ),
              const SizedBox(width: DesignConstants.spacingMd),
              // 信息区域
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 名称行：中文名大字 + 原名淡色小字跟在后面
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            character.displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (character.subName != null) ...[
                          const SizedBox(width: DesignConstants.spacingSm),
                          Flexible(
                            child: Text(
                              character.subName!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.hintColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: DesignConstants.spacingSm),
                    // Tags 行
                    Wrap(
                      spacing: DesignConstants.spacingSm,
                      runSpacing: DesignConstants.spacingXs,
                      children: [
                        // 角色类型 tag (主角/配角等)
                        if (character.roleName != null &&
                            character.roleName!.isNotEmpty)
                          _buildTag(
                            context,
                            character.roleName!,
                            theme.colorScheme.primaryContainer,
                            theme.colorScheme.onPrimaryContainer,
                          ),
                        // 生日 tag
                        _buildBirthdayTag(context, theme, character),
                      ],
                    ),
                  ],
                ),
              ),
              // 选中状态指示或箭头
              if (!widget.isSelectionMode)
                Icon(Icons.chevron_right, color: theme.hintColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBirthdayTag(
    BuildContext context,
    ThemeData theme,
    BangumiCharacterDto character,
  ) {
    if (character.hasBirthday) {
      // 有生日
      return _buildTag(
        context,
        character.birthdayText!,
        theme.colorScheme.tertiaryContainer,
        theme.colorScheme.onTertiaryContainer,
        icon: Icons.cake_outlined,
      );
    } else if (_isLoading) {
      // 加载中
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignConstants.tagPaddingH,
          vertical: DesignConstants.tagPaddingV,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(DesignConstants.tagRadius),
        ),
        child: SizedBox(
          width: DesignConstants.iconSizeSm,
          height: DesignConstants.iconSizeSm,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    } else if (_fullCharacter != null && !_fullCharacter!.hasBirthday) {
      // 已获取详情但无生日
      return _buildTag(
        context,
        '无生日',
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
      );
    } else {
      // 还没加载
      return const SizedBox.shrink();
    }
  }

  Widget _buildTag(
    BuildContext context,
    String text,
    Color bgColor,
    Color textColor, {
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignConstants.tagPaddingH,
        vertical: DesignConstants.tagPaddingV,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(DesignConstants.tagRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: DesignConstants.iconSizeSm, color: textColor),
            const SizedBox(width: DesignConstants.spacingXs),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: DesignConstants.tagFontSize,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 用于列表复选的角色项（简化版）- 保留兼容
class BangumiCharacterCheckItem extends StatelessWidget {
  final BangumiCharacterDto character;
  final bool isSelected;
  final ValueChanged<bool?>? onChanged;

  const BangumiCharacterCheckItem({
    super.key,
    required this.character,
    this.isSelected = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BangumiCharacterListItem(
      character: character,
      isSelected: isSelected,
      isSelectionMode: true,
      onCheckChanged: onChanged,
    );
  }
}
