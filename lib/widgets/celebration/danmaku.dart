import 'dart:math';
import 'package:flutter/material.dart';

/// 弹幕项数据
class DanmakuItem {
  String text;
  double x; // 0.0 to 1.2
  double y; // 0.0 to 1.0
  double speed;
  double opacity;
  Color color;
  double fontSize;

  DanmakuItem({
    required this.text,
    required this.x,
    required this.y,
    required this.speed,
    required this.opacity,
    required this.color,
    required this.fontSize,
  });
}

/// 弹幕 CustomPainter
class DanmakuPainter extends CustomPainter {
  final List<DanmakuItem> items;
  DanmakuPainter(this.items);

  @override
  void paint(Canvas canvas, Size size) {
    for (var item in items) {
      final textSpan = TextSpan(
        text: item.text,
        style: TextStyle(
          color: item.color.withAlpha((item.opacity * 255).round()),
          fontSize: item.fontSize,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              blurRadius: 3,
              color: Colors.black.withAlpha(77),
              offset: const Offset(1, 1),
            ),
          ],
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(item.x * size.width, item.y * size.height),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 弹幕生成与更新工具
class DanmakuGenerator {
  static final Random _random = Random();

  static const List<Color> _colors = [
    Colors.white,
    Color(0xFFF8BBD0), // pink.shade100
    Color(0xFFFFF9C4), // yellow.shade100
    Color(0xFFB2EBF2), // cyan.shade100
    Color(0xFFFFD700),
  ];

  /// 生成一条弹幕（8% 概率），避开中间区域
  ///
  /// [avoidYStart] ~ [avoidYEnd] 指定垂直方向避让区间（例如头像区域）
  static DanmakuItem? tryGenerate({
    required List<String> greetings,
    double avoidYStart = 0.4,
    double avoidYEnd = 0.6,
  }) {
    if (_random.nextInt(100) >= 8) return null;

    double itemY = _random.nextDouble();
    if (itemY > avoidYStart && itemY < avoidYEnd) {
      itemY = itemY < (avoidYStart + avoidYEnd) / 2
          ? avoidYStart - 0.1
          : avoidYEnd + 0.1;
    }

    return DanmakuItem(
      text: greetings[_random.nextInt(greetings.length)],
      x: 1.2,
      y: 0.05 + itemY.clamp(0.0, 1.0) * 0.9,
      speed: 0.003 + _random.nextDouble() * 0.005,
      opacity: 0.3 + _random.nextDouble() * 0.3,
      color: _colors[_random.nextInt(_colors.length)],
      fontSize: 20 + _random.nextDouble() * 20,
    );
  }

  /// 更新所有弹幕位置，并移除已飞出屏幕的
  static void updateAll(List<DanmakuItem> items) {
    for (var item in items) {
      item.x -= item.speed;
    }
    items.removeWhere((item) => item.x < -0.8);
  }
}
