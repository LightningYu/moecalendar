import 'package:flutter/material.dart';
import '../bangumi/bangumi.dart';
import '../config/design_constants.dart';

/// 番剧条目列表项组件
/// 用于展示番剧收藏列表，使用较大的封面图
class BangumiSubjectListItem extends StatelessWidget {
  final BangumiSubjectDto subject;
  final VoidCallback? onTap;

  const BangumiSubjectListItem({super.key, required this.subject, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = subject.nameCn.isNotEmpty
        ? subject.nameCn
        : subject.name;
    final subName = subject.nameCn.isNotEmpty ? subject.name : null;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: DesignConstants.cardMarginH,
        vertical: DesignConstants.cardMarginV,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(DesignConstants.cardPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面图 - 使用较大尺寸展示高精度图片
              ClipRRect(
                borderRadius: BorderRadius.circular(DesignConstants.spacingSm),
                child: Container(
                  width: DesignConstants.avatarSizeLg,
                  height: 110,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: subject.image != null
                      ? Image.network(
                          subject.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.movie_outlined,
                            size: 32,
                            color: theme.hintColor,
                          ),
                        )
                      : Icon(
                          Icons.movie_outlined,
                          size: 32,
                          color: theme.hintColor,
                        ),
                ),
              ),
              const SizedBox(width: DesignConstants.spacing),
              // 信息区域
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subName != null) ...[
                      const SizedBox(height: DesignConstants.spacingXs),
                      Text(
                        subName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // 箭头指示
              Icon(Icons.chevron_right, color: theme.hintColor),
            ],
          ),
        ),
      ),
    );
  }
}
