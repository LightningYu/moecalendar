import 'package:flutter/material.dart';

/// 名字首字头像组件
///
/// 用于手动创建的角色和"你"，以名字首字代替默认 icon。
/// Bangumi 角色在没有本地图片时也会用此显示。
class NameAvatarWidget extends StatelessWidget {
  final String name;
  final double size;
  final bool isSelf;
  final TextStyle? textStyle;

  const NameAvatarWidget({
    super.key,
    required this.name,
    this.size = 64,
    this.isSelf = false,
    this.textStyle,
  });

  /// 根据名字生成稳定的颜色
  Color _generateColor(BuildContext context) {
    if (isSelf) {
      return Theme.of(context).colorScheme.primaryContainer;
    }
    // 根据名字 hashCode 生成一个柔和的颜色
    final hash = name.hashCode.abs();
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
    final bgColor = _generateColor(context);
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
