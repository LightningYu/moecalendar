import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/character_model.dart';
import '../../utils/zodiac_utils.dart';
import '../../config/app_strings.dart';

class CongratulationScreen extends StatefulWidget {
  final Character character;
  const CongratulationScreen({super.key, required this.character});

  @override
  State<CongratulationScreen> createState() => _CongratulationScreenState();
}

class _CongratulationScreenState extends State<CongratulationScreen>
    with TickerProviderStateMixin {
  late AnimationController _celebrationController;
  final List<ConfettiItem> _particles = [];
  final Random _random = Random();

  // Age Logic
  late Timer _timer;
  double _preciseAge = 0.0;
  bool _isBirthday = false;
  bool _celebrationTriggered = false;

  // Danmaku
  final List<DanmakuItem> _danmakuList = [];
  late AnimationController _danmakuController;

  // Text Animation
  bool _showNormalText = true;
  bool _showCelebrationText = false;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..repeat();

    _danmakuController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Initialize confetti particles
    for (int i = 0; i < 60; i++) {
      _particles.add(_generateConfetti());
    }

    _celebrationController.addListener(() {
      if (!mounted) return;
      setState(() {
        _updateParticles();
        if (_isBirthday) {
          _updateDanmaku();
        }
      });
    });

    _updateTime();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      _updateTime();
    });
  }

  ConfettiItem _generateConfetti() {
    return ConfettiItem(
      x: _random.nextDouble(),
      y: _random.nextDouble() * 1.5 - 0.5,
      speedY: 0.002 + _random.nextDouble() * 0.004,
      speedX: -0.001 + _random.nextDouble() * 0.002,
      rotation: _random.nextDouble() * pi * 2,
      rotationSpeed: -0.1 + _random.nextDouble() * 0.2,
      color: [
        Colors.redAccent,
        Colors.orangeAccent,
        Colors.yellowAccent,
        Colors.greenAccent,
        Colors.blueAccent,
        Colors.pinkAccent,
        Colors.purpleAccent,
        const Color(0xFFFFD700),
      ][_random.nextInt(8)],
      width: 6 + _random.nextDouble() * 8,
      height: 4 + _random.nextDouble() * 6,
    );
  }

  void _updateTime() {
    if (widget.character.birthYear == null) return;

    final now = DateTime.now();
    final birthDate = DateTime(
      widget.character.birthYear!,
      widget.character.birthMonth,
      widget.character.birthDay,
    );

    // Check if it is birthday TODAY
    final isBirthdayToday = ZodiacUtils.isBirthdayToday(
      widget.character.birthMonth,
      widget.character.birthDay,
      widget.character.isLunar,
    );

    // Calculate precise age
    const msPerYear = 31556952000.0;
    final age = now.difference(birthDate).inMilliseconds / msPerYear;

    if (isBirthdayToday && !_celebrationTriggered) {
      _triggerCelebration();
    }

    setState(() {
      _preciseAge = age;
      _isBirthday = isBirthdayToday;
    });
  }

  void _triggerCelebration() async {
    _celebrationTriggered = true;
    setState(() {
      _showNormalText = false;
    });
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        _showCelebrationText = true;
      });
    }
  }

  void _updateParticles() {
    for (var p in _particles) {
      p.y += p.speedY;
      p.x += p.speedX;
      p.rotation += p.rotationSpeed;
      if (p.y > 1.1) {
        p.y = -0.1;
        p.x = _random.nextDouble();
      }
    }
  }

  void _updateDanmaku() {
    // 降低密度并大幅提高透明度以避免遮挡
    if (_random.nextInt(100) < 8) {
      final greetings = AppStrings.birthdayGreetings;
      // 避开 0.4 - 0.6 的垂直区域 (文字聚集区)
      double itemY = _random.nextDouble();
      if (itemY > 0.4 && itemY < 0.6) {
        itemY = itemY < 0.5 ? 0.3 : 0.7;
      }

      _danmakuList.add(
        DanmakuItem(
          text: greetings[_random.nextInt(greetings.length)],
          x: 1.2,
          y: 0.05 + itemY * 0.9,
          speed: 0.003 + _random.nextDouble() * 0.005,
          opacity: 0.3 + _random.nextDouble() * 0.3, // 降低透明度
          color: [
            Colors.white,
            Colors.pink.shade100,
            Colors.yellow.shade100,
            Colors.cyan.shade100,
            const Color(0xFFFFD700),
          ][_random.nextInt(5)],
          fontSize: 20 + _random.nextDouble() * 20,
        ),
      );
    }

    for (var item in _danmakuList) {
      item.x -= item.speed;
    }
    _danmakuList.removeWhere((item) => item.x < -0.8);
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    _danmakuController.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zodiac = ZodiacUtils.getZodiac(
      widget.character.birthMonth,
      widget.character.birthDay,
    );
    final integerAge = _preciseAge.floor();

    return Scaffold(
      body: Stack(
        children: [
          // Background - Festive Red/Pink Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFCC2B5E), Color(0xFF753A88)],
                ),
              ),
            ),
          ),
          // Confetti
          Positioned.fill(
            child: CustomPaint(painter: ConfettiPainter(_particles)),
          ),
          // Danmaku Layer
          if (_isBirthday)
            Positioned.fill(
              child: CustomPaint(painter: DanmakuPainter(_danmakuList)),
            ),
          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // State 1: Not Birthday
                if (_showNormalText)
                  AnimatedOpacity(
                    opacity: _showNormalText ? 1.0 : 0.0,
                    duration: const Duration(seconds: 1),
                    child: Column(
                      children: [
                        const Text(
                          '你已经',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 24,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _preciseAge.toStringAsFixed(9),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            shadows: [
                              Shadow(blurRadius: 10, color: Colors.black26),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          '岁了',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 24,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),

                // State 2: Birthday Celebration
                if (_celebrationTriggered)
                  AnimatedOpacity(
                    opacity: _showCelebrationText ? 1.0 : 0.0,
                    duration: const Duration(seconds: 2),
                    child: Column(
                      children: [
                        const Text(
                          '生日快乐',
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 60,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            shadows: [
                              Shadow(
                                blurRadius: 20,
                                color: Colors.orangeAccent,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          '$integerAge 岁',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '尊贵的 $zodiac 守护者',
                          style: const TextStyle(
                            color: Colors.white, // 提高对比度
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            shadows: [
                              Shadow(blurRadius: 8, color: Colors.black26),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Back Button
          Positioned(
            top: 40,
            left: 10,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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

class DanmakuPainter extends CustomPainter {
  final List<DanmakuItem> items;

  DanmakuPainter(this.items);

  @override
  void paint(Canvas canvas, Size size) {
    for (var item in items) {
      final textSpan = TextSpan(
        text: item.text,
        style: TextStyle(
          color: item.color.withOpacity(item.opacity),
          fontSize: item.fontSize,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              blurRadius: 3,
              color: Colors.black.withOpacity(0.3),
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
