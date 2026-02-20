import 'dart:io';
import 'package:flutter/material.dart';
import '../config/design_constants.dart';
import '../services/task_pool_service.dart';
import 'name_avatar_widget.dart';

/// 通用角色头像组件
///
/// 支持：
/// - 本地文件图片 / 网络图片 / 名字首字占位
/// - Bangumi 角色的后台下载进度指示
/// - 下载失败标记
class CharacterAvatarWidget extends StatelessWidget {
  /// 图片路径（本地路径或网络 URL）
  final String? imagePath;

  /// 角色名（用于生成首字占位）
  final String name;

  /// 头像尺寸
  final double size;

  /// 是否为"我自己"
  final bool isSelf;

  /// 角色 ID（用于查询下载状态）
  final String? characterId;

  /// 是否为 Bangumi 角色（才会查询下载进度）
  final bool isBangumi;

  /// 头像背景色（ARGB int），来自 Character.avatarColor
  final int? avatarColor;

  const CharacterAvatarWidget({
    super.key,
    this.imagePath,
    required this.name,
    this.size = DesignConstants.avatarSizeSm,
    this.isSelf = false,
    this.characterId,
    this.isBangumi = false,
    this.avatarColor,
  });

  bool _isLocalFile(String? p) {
    if (p == null) return false;
    if (p.startsWith('http')) return false;
    return File(p).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskPool = TaskPoolService();
    final task = (isBangumi && characterId != null)
        ? taskPool.getTaskByCharacterId(characterId!)
        : null;
    final isDownloading =
        task != null &&
        (task.status == TaskStatus.running ||
            task.status == TaskStatus.pending);
    final isFailed = task != null && task.status == TaskStatus.failed;

    final hasLocalImage = _isLocalFile(imagePath);
    final hasNetworkImage = imagePath != null && imagePath!.startsWith('http');

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // 底层头像
          ClipRRect(
            borderRadius: BorderRadius.circular(DesignConstants.radiusMd),
            child: Container(
              width: size,
              height: size,
              color: theme.colorScheme.surfaceContainerHighest,
              child: hasLocalImage
                  ? Image(
                      image: FileImage(File(imagePath!)),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildFallback(),
                    )
                  : hasNetworkImage
                  ? Image(
                      image: NetworkImage(imagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildFallback(),
                    )
                  : _buildFallback(),
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
                      width: size * 0.44,
                      height: size * 0.44,
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

  Widget _buildFallback() {
    final displayName = isSelf ? '你' : name;
    return NameAvatarWidget(
      name: displayName,
      size: size,
      isSelf: isSelf,
      avatarColor: avatarColor,
    );
  }
}
