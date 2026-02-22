import 'dart:math';
import 'package:flutter/material.dart';

/// 五彩纸屑粒子数据
class ConfettiItem {
  double x, y, speedY, speedX, rotation, rotationSpeed, width, height;
  Color color;

  ConfettiItem({
    required this.x,
    required this.y,
    required this.speedY,
    required this.speedX,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.width,
    required this.height,
  });
}

/// 五彩纸屑 CustomPainter
class ConfettiPainter extends CustomPainter {
  final List<ConfettiItem> particles;
  ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var p in particles) {
      paint.color = p.color;
      canvas.save();
      canvas.translate(p.x * size.width, p.y * size.height);
      canvas.rotate(p.rotation);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.width, height: p.height),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 五彩纸屑生成工具
class ConfettiGenerator {
  static final Random _random = Random();

  static const List<Color> _colors = [
    Colors.redAccent,
    Colors.orangeAccent,
    Colors.yellowAccent,
    Colors.greenAccent,
    Colors.blueAccent,
    Colors.pinkAccent,
    Colors.purpleAccent,
    Color(0xFFFFD700),
  ];

  /// 生成单个五彩纸屑粒子
  static ConfettiItem generate({double maxWidth = 10, double maxHeight = 6}) {
    return ConfettiItem(
      x: _random.nextDouble(),
      y: _random.nextDouble() * 1.5 - 0.5,
      speedY: 0.002 + _random.nextDouble() * 0.004,
      speedX: -0.001 + _random.nextDouble() * 0.002,
      rotation: _random.nextDouble() * pi * 2,
      rotationSpeed: -0.1 + _random.nextDouble() * 0.2,
      color: _colors[_random.nextInt(_colors.length)],
      width: 6 + _random.nextDouble() * maxWidth,
      height: 4 + _random.nextDouble() * maxHeight,
    );
  }

  /// 批量生成
  static List<ConfettiItem> generateBatch(int count) {
    return List.generate(count, (_) => generate());
  }

  /// 更新所有粒子位置
  static void updateAll(List<ConfettiItem> particles) {
    for (var p in particles) {
      p.y += p.speedY;
      p.x += p.speedX;
      p.rotation += p.rotationSpeed;
      if (p.y > 1.1) {
        p.y = -0.1;
        p.x = _random.nextDouble();
      }
    }
  }
}
