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
  late AnimationController _starController;
  final List<Particle> _particles = [];
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
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _danmakuController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20), // Loop duration, not item speed
    )..repeat();

    // Initialize particles
    for (int i = 0; i < 50; i++) {
      _particles.add(_generateParticle());
    }

    _starController.addListener(() {
      if (!mounted) return;
      setState(() {
        _updateParticles();
      });
    });

    _danmakuController.addListener(() {
      if (!mounted) return;
      if (_isBirthday) {
        _updateDanmaku();
      }
    });

    _updateTime();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      _updateTime();
    });
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

    // Fade out normal text
    setState(() {
      _showNormalText = false;
    });

    await Future.delayed(const Duration(seconds: 1));

    // Fade in celebration text
    if (mounted) {
      setState(() {
        _showCelebrationText = true;
      });
    }
  }

  void _updateParticles() {
    for (var particle in _particles) {
      particle.y -= particle.speed;
      particle.opacity += particle.twinkleSpeed;
      if (particle.opacity >= 1.0) {
        particle.opacity = 1.0;
        particle.twinkleSpeed = -particle.twinkleSpeed;
      } else if (particle.opacity <= 0.2) {
        particle.opacity = 0.2;
        particle.twinkleSpeed = -particle.twinkleSpeed;
      }
      if (particle.y < 0) {
        _resetParticle(particle);
      }
    }
  }

  void _updateDanmaku() {
    // Spawn new danmaku randomly
    if (_random.nextInt(100) < 2) {
      // 2% chance per frame
      final greetings = AppStrings.birthdayGreetings;
      _danmakuList.add(
        DanmakuItem(
          text: greetings[_random.nextInt(greetings.length)],
          x: 1.2, // Start off-screen right (relative to width)
          y: 0.1 + _random.nextDouble() * 0.8, // Random height
          speed: 0.002 + _random.nextDouble() * 0.003,
          color: Colors.primaries[_random.nextInt(Colors.primaries.length)],
          fontSize: 20 + _random.nextDouble() * 20,
        ),
      );
    }

    // Move existing danmaku
    for (var item in _danmakuList) {
      item.x -= item.speed;
    }

    // Remove off-screen danmaku
    _danmakuList.removeWhere((item) => item.x < -1);
  }

  Particle _generateParticle() {
    return Particle(
      x: _random.nextDouble(),
      y: _random.nextDouble(), // Start anywhere
      speed: 0.0002 + _random.nextDouble() * 0.0005, // Very slow drift
      color: Colors.white,
      size: 1 + _random.nextDouble() * 3, // Small stars
      opacity: 0.2 + _random.nextDouble() * 0.8,
      twinkleSpeed:
          (_random.nextBool() ? 1 : -1) * (0.005 + _random.nextDouble() * 0.01),
    );
  }

  void _resetParticle(Particle p) {
    p.x = _random.nextDouble();
    p.y = 1.0 + _random.nextDouble() * 0.1; // Start at bottom
    p.speed = 0.0002 + _random.nextDouble() * 0.0005;
    p.opacity = 0.2 + _random.nextDouble() * 0.8;
    p.size = 1 + _random.nextDouble() * 3;
    p.twinkleSpeed =
        (_random.nextBool() ? 1 : -1) * (0.005 + _random.nextDouble() * 0.01);
  }

  @override
  void dispose() {
    _starController.dispose();
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
          // Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0B1026), Color(0xFF2B32B2)],
                ),
              ),
            ),
          ),
          // Stars
          Positioned.fill(
            child: CustomPaint(painter: StarrySkyPainter(_particles)),
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
                // State 1: Not Birthday (or before animation trigger)
                AnimatedOpacity(
                  opacity: _showNormalText ? 1.0 : 0.0,
                  duration: const Duration(seconds: 1),
                  child: _showNormalText
                      ? Column(
                          children: [
                            const Text(
                              '已经',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 24,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _preciseAge.toStringAsFixed(9),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              '岁了',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 24,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
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
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                blurRadius: 20.0,
                                color: Colors.pink,
                                offset: Offset(0, 0),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '$integerAge 岁',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          '$zodiac 的你',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 24,
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
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class Particle {
  double x;
  double y;
  double speed;
  Color color;
  double size;
  double opacity;
  double twinkleSpeed; // New property for twinkling

  Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.color,
    required this.size,
    required this.opacity,
    required this.twinkleSpeed,
  });
}

class StarrySkyPainter extends CustomPainter {
  final List<Particle> particles;

  StarrySkyPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final paint = Paint()
        ..color = p.color.withOpacity(p.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class DanmakuItem {
  String text;
  double x; // 0.0 to 1.0+
  double y; // 0.0 to 1.0
  double speed;
  Color color;
  double fontSize;

  DanmakuItem({
    required this.text,
    required this.x,
    required this.y,
    required this.speed,
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
          color: item.color,
          fontSize: item.fontSize,
          fontWeight: FontWeight.bold,
          shadows: const [
            Shadow(blurRadius: 2, color: Colors.black, offset: Offset(1, 1)),
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
