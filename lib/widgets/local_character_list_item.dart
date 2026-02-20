import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/character_model.dart';
import '../utils/zodiac_utils.dart';
import '../config/design_constants.dart';
import '../services/image_download_service.dart';
import 'name_avatar_widget.dart';

/// 本地已保存角色的列表项组件
/// 用于 character_tab.dart 中展示已添加的角色
/// 支持：点击进入详情、长按进入多选模式、显示生日倒计时
class LocalCharacterListItem extends StatelessWidget {
  final Character character;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool?>? onCheckChanged;

  const LocalCharacterListItem({
    super.key,
    required this.character,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onTap,
    this.onLongPress,
    this.onCheckChanged,
  });

  int _calculateDaysLeft() {
    final now = DateTime.now();
    final nextBirthday = ZodiacUtils.getNextBirthday(character);
    return nextBirthday.difference(now).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBangumi = character is BangumiCharacter;
    final isSelf =
        character is ManualCharacter && (character as ManualCharacter).isSelf;
    // Bangumi 角色在列表中使用 grid 头像
    final avatarPath = isBangumi
        ? (character as BangumiCharacter).listAvatar
        : character.avatarPath;
    final daysLeft = _calculateDaysLeft();

    // 生日格式化
    final birthdayText = character.birthYear != null
        ? DateFormat('yyyy年MM月dd日').format(character.date)
        : DateFormat('MM月dd日').format(character.date);

    // 显示名称：自己显示为"你"
    final displayName = isSelf ? '你' : character.name;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: DesignConstants.cardMarginH,
        vertical: DesignConstants.cardMarginV,
      ),
      clipBehavior: Clip.antiAlias,
      // 自己使用特殊边框
      shape: isSelf
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignConstants.cardRadius),
              side: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
                width: 2,
              ),
            )
          : null,
      child: InkWell(
        onTap: isSelectionMode
            ? () => onCheckChanged?.call(!isSelected)
            : onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(DesignConstants.cardPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 多选模式下显示复选框
              if (isSelectionMode) ...[
                Checkbox(value: isSelected, onChanged: onCheckChanged),
                const SizedBox(width: DesignConstants.spacingSm),
              ],
              // 头像（含下载进度）
              _buildAvatarWithProgress(
                context,
                theme,
                avatarPath: avatarPath,
                isBangumi: isBangumi,
                isSelf: isSelf,
              ),
              const SizedBox(width: DesignConstants.spacingMd),
              // 信息区域
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 名称
                    Text(
                      displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelf ? theme.colorScheme.primary : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: DesignConstants.spacingXs),
                    // 生日
                    Row(
                      children: [
                        Icon(
                          Icons.cake_outlined,
                          size: DesignConstants.iconSizeMd,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: DesignConstants.spacingXs),
                        Text(
                          birthdayText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignConstants.spacingSm),
                    // Tags 行
                    Wrap(
                      spacing: DesignConstants.spacingSm,
                      runSpacing: DesignConstants.spacingXs,
                      children: [
                        // 来源类型 tag
                        _buildTag(
                          context,
                          isSelf ? '我自己' : (isBangumi ? 'Bangumi' : '手动添加'),
                          isSelf
                              ? theme.colorScheme.primaryContainer
                              : (isBangumi
                                    ? theme.colorScheme.primaryContainer
                                    : theme.colorScheme.secondaryContainer),
                          isSelf
                              ? theme.colorScheme.onPrimaryContainer
                              : (isBangumi
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSecondaryContainer),
                        ),
                        // 倒计时 tag
                        _buildDaysTag(context, theme, daysLeft),
                      ],
                    ),
                  ],
                ),
              ),
              // 选中状态指示或箭头
              if (!isSelectionMode)
                Icon(
                  isSelf ? Icons.edit : Icons.chevron_right,
                  color: isSelf ? theme.colorScheme.primary : theme.hintColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 判断路径是否为有效的本地文件路径（非网络 URL）
  bool _isLocalFile(String? p) {
    if (p == null) return false;
    if (p.startsWith('http')) return false;
    return File(p).existsSync();
  }

  /// 构建带下载进度的头像
  Widget _buildAvatarWithProgress(
    BuildContext context,
    ThemeData theme, {
    required String? avatarPath,
    required bool isBangumi,
    required bool isSelf,
  }) {
    final downloadService = ImageDownloadService();
    final task = isBangumi ? downloadService.getTask(character.id) : null;
    final isDownloading =
        task != null &&
        (task.status == DownloadStatus.downloading ||
            task.status == DownloadStatus.pending);
    final isFailed = task != null && task.status == DownloadStatus.failed;

    final hasLocalImage = _isLocalFile(avatarPath);
    final hasNetworkImage = avatarPath != null && avatarPath.startsWith('http');

    return SizedBox(
      width: DesignConstants.avatarSizeSm,
      height: DesignConstants.avatarSizeSm,
      child: Stack(
        children: [
          // 底层头像
          ClipRRect(
            borderRadius: BorderRadius.circular(DesignConstants.radiusMd),
            child: Container(
              width: DesignConstants.avatarSizeSm,
              height: DesignConstants.avatarSizeSm,
              color: theme.colorScheme.surfaceContainerHighest,
              child: hasLocalImage
                  ? Image(
                      image: FileImage(File(avatarPath!)),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildNameAvatar(isSelf),
                    )
                  : hasNetworkImage
                  ? Image(
                      image: NetworkImage(avatarPath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildNameAvatar(isSelf),
                    )
                  : _buildNameAvatar(isSelf),
            ),
          ),
          // 下载中遮罩 + 进度
          if (isDownloading)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DesignConstants.radiusMd),
                child: Container(
                  color: Colors.black38,
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        value: task.progress > 0 ? task.progress : null,
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // 下载失败标记
          if (isFailed && !hasLocalImage)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.refresh,
                  size: 14,
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNameAvatar(bool isSelf) {
    final displayName = isSelf ? '你' : character.name;
    return NameAvatarWidget(
      name: displayName,
      size: DesignConstants.avatarSizeSm,
      isSelf: isSelf,
    );
  }

  Widget _buildDaysTag(BuildContext context, ThemeData theme, int daysLeft) {
    Color bgColor;
    Color textColor;
    String text;

    if (daysLeft == 0) {
      bgColor = theme.colorScheme.errorContainer;
      textColor = theme.colorScheme.onErrorContainer;
      text = '🎂 今天生日！';
    } else if (daysLeft <= 7) {
      bgColor = theme.colorScheme.tertiaryContainer;
      textColor = theme.colorScheme.onTertiaryContainer;
      text = '⏰ 还有 $daysLeft 天';
    } else if (daysLeft <= 30) {
      bgColor = theme.colorScheme.secondaryContainer;
      textColor = theme.colorScheme.onSecondaryContainer;
      text = '还有 $daysLeft 天';
    } else {
      bgColor = theme.colorScheme.surfaceContainerHighest;
      textColor = theme.colorScheme.onSurfaceVariant;
      text = '还有 $daysLeft 天';
    }

    return _buildTag(context, text, bgColor, textColor);
  }

  Widget _buildTag(
    BuildContext context,
    String text,
    Color bgColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignConstants.tagPaddingH,
        vertical: DesignConstants.tagPaddingV,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(DesignConstants.tagRadius),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: DesignConstants.tagFontSize,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
