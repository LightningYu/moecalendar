import 'package:flutter/material.dart';

/// 名字首字头像组件
///
/// 用于手动创建的角色和"你"，以名字首字代替默认 icon。
/// Bangumi 角色在没有本地图片时也会用此显示。
///
/// 颜色优先使用外部传入的 [avatarColor]（持久化在 model 中），
/// 若未提供则使用确定性 hash 生成（向后兼容旧数据）。
class NameAvatarWidget extends StatelessWidget {
  final String name;
  final double size;
  final bool isSelf;
  final TextStyle? textStyle;

  /// 外部传入的头像背景色（ARGB int），来自 Character.avatarColor
  final int? avatarColor;

  const NameAvatarWidget({
    super.key,
    required this.name,
    this.size = 64,
    this.isSelf = false,
    this.textStyle,
    this.avatarColor,
  });

  /// 获取背景色：优先使用外部传入的持久化颜色，否则 fallback 到 hash
  Color _getBackgroundColor(BuildContext context) {
    if (isSelf) {
      return Theme.of(context).colorScheme.primaryContainer;
    }
    if (avatarColor != null) {
      return Color(avatarColor!);
    }
    // Fallback：确定性 hash（兼容没有 avatarColor 的旧数据）
    int hash = 0x811c9dc5;
    for (final codeUnit in name.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.35, 0.75).toColor();
  }

  String _getInitial() {
    if (name.isEmpty) return '?';
    // 如果是"你"，直接返回
    if (isSelf) return '你';
    // 取第一个字符
    final runes = name.runes.toList();
    return String.fromCharCode(runes.first);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = _getBackgroundColor(context);
    final initial = _getInitial();
    final fontSize = size * 0.4;

    // 对比色
    final textColor = isSelf
        ? theme.colorScheme.onPrimaryContainer
        : ThemeData.estimateBrightnessForColor(bgColor) == Brightness.light
        ? Colors.black87
        : Colors.white;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(size * 0.18),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style:
            textStyle ??
            TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: textColor,
              height: 1.0,
            ),
      ),
    );
  }
}
