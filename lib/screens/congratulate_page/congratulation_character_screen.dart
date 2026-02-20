import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/character_model.dart';
import '../../utils/zodiac_utils.dart';
import '../../config/design_constants.dart';

class CongratulationCharacterScreen extends StatefulWidget {
  final List<Character> characters;
  const CongratulationCharacterScreen({super.key, required this.characters});

  @override
  State<CongratulationCharacterScreen> createState() =>
      _CongratulationCharacterScreenState();
}

class _CongratulationCharacterScreenState
    extends State<CongratulationCharacterScreen>
    with TickerProviderStateMixin {
  // Phase 1: Countdown
  int _countdown = 20; // Default if check fails
  Timer? _countdownTimer;
  bool _isPhase1 = true;

  // Phase 2: Celebration
  late AnimationController _danmakuController;
  late AnimationController _pulseController;
  late AnimationController _glowController;
  final List<DanmakuItem> _danmakuList = [];
  final List<ConfettiItem> _particles = [];
  final Random _random = Random();

  final List<String> _birthdayGreetings = [
    'Happy Birthday',
    '生日快乐',
    'お誕生日おめでとう',
    '생일 축하합니다',
    'Joyeux Anniversaire',
    'Alles Gute zum Geburtstag',
    'Feliz Cumpleaños',
    'С Днем Рождения',
    'Buon Compleanno',
  ];

  @override
  void initState() {
    super.initState();
    _checkPhase();

    _danmakuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _danmakuController.addListener(() {
      if (!mounted) return;
      if (!_isPhase1) {
        setState(() {
          _updateDanmaku();
          _updateParticles();
        });
      }
    });

    // 预生成五彩纸屑
    for (int i = 0; i < 80; i++) {
      _particles.add(_generateConfetti());
    }
  }

  ConfettiItem _generateConfetti() {
    return ConfettiItem(
      x: _random.nextDouble(),
      y: _random.nextDouble() * 1.5 - 0.5,
      speedY: 0.003 + _random.nextDouble() * 0.005,
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
      width: 6 + _random.nextDouble() * 10,
      height: 4 + _random.nextDouble() * 6,
    );
  }

  void _checkPhase() {
    if (widget.characters.isEmpty) {
      setState(() => _isPhase1 = false);
      return;
    }

    final now = DateTime.now();
    final nextBirthday = ZodiacUtils.getNextBirthday(widget.characters.first);
    final diff = nextBirthday.difference(now).inSeconds;

    // If within 30 seconds of birthday, start countdown
    if (diff > 0 && diff <= 30) {
      setState(() {
        _countdown = diff;
        _isPhase1 = true;
      });
      _startCountdown();
    } else {
      // Otherwise (already birthday or far away), skip to Phase 2
      setState(() {
        _isPhase1 = false;
      });
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        _countdownTimer?.cancel();
        setState(() {
          _isPhase1 = false;
        });
      }
    });
  }

  void _updateDanmaku() {
    // 降低弹幕密度 (8% 概率) 并避开中间，降低透明度
    if (_random.nextInt(100) < 8) {
      // 避开 0.35 - 0.65 的垂直区域 (头像和文字区)
      double itemY = _random.nextDouble();
      if (itemY > 0.35 && itemY < 0.65) {
        itemY = itemY < 0.5 ? 0.25 : 0.75;
      }

      _danmakuList.add(
        DanmakuItem(
          text: _birthdayGreetings[_random.nextInt(_birthdayGreetings.length)],
          x: 1.2,
          y: 0.1 + itemY * 0.8,
          speed: 0.003 + _random.nextDouble() * 0.005,
          opacity: 0.3 + _random.nextDouble() * 0.3, // 显著降低透明度
          color: [
            Colors.white,
            Colors.pink.shade100,
            Colors.yellow.shade100,
            Colors.cyan.shade100,
            const Color(0xFFFFD700),
          ][_random.nextInt(5)],
          fontSize: 22 + _random.nextDouble() * 18,
        ),
      );
    }

    for (var item in _danmakuList) {
      item.x -= item.speed;
    }
    _danmakuList.removeWhere((item) => item.x < -0.8);
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

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _danmakuController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background - Festive Red Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE52D27),
                  Color(0xFFB31217),
                  Color(0xFF700111),
                ],
              ),
            ),
          ),

          // Particles (Confetti)
          if (!_isPhase1)
            CustomPaint(
              painter: ConfettiPainter(_particles),
              size: Size.infinite,
            ),

          // Phase 1: Countdown
          if (_isPhase1) _buildCountdownPhase(),

          // Phase 2: Celebration
          if (!_isPhase1) ...[
            // Danmaku
            CustomPaint(
              painter: DanmakuPainter(_danmakuList),
              size: Size.infinite,
            ),
            // Main Content
            Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  vertical: DesignConstants.spacingXl,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: widget.characters.map((c) {
                    return _buildCharacterGreeting(c);
                  }).toList(),
                ),
              ),
            ),
          ],

          // Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => context.pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownPhase() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '即将揭晓...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w300,
              letterSpacing: 8,
            ),
          ),
          const SizedBox(height: 60),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 260,
                height: 260,
                child: CircularProgressIndicator(
                  value: _countdown / 30,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.white10,
                  color: Colors.orangeAccent,
                ),
              ),
              ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.2).animate(
                  CurvedAnimation(
                    parent: _pulseController,
                    curve: Curves.elasticOut,
                  ),
                ),
                child: Text(
                  '$_countdown',
                  style: const TextStyle(
                    fontSize: 120,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'monospace',
                    shadows: [
                      Shadow(blurRadius: 20, color: Colors.orangeAccent),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterGreeting(Character c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0),
      child: Column(
        children: [
          // 蛋糕图标作为装饰
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white10,
              boxShadow: [
                BoxShadow(
                  color: Colors.orangeAccent.withOpacity(0.3),
                  blurRadius: 60,
                  spreadRadius: 20,
                ),
              ],
            ),
            child: const Icon(
              Icons.cake_rounded,
              size: 100,
              color: Color(0xFFFFD700),
            ),
          ),
          const SizedBox(height: 48),
          ShaderMask(
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                colors: const [
                  Color(0xFFFFD700),
                  Colors.white,
                  Color(0xFFFFD700),
                ],
                stops: const [0.0, 0.5, 1.0],
                transform: GradientRotation(_glowController.value * pi * 2),
              ).createShader(bounds);
            },
            child: const Text(
              '生日快乐',
              style: TextStyle(
                color: Colors.white,
                fontSize: 64,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                shadows: [
                  Shadow(
                    blurRadius: 15,
                    color: Colors.black45,
                    offset: Offset(3, 3),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            c.name,
            style: const TextStyle(
              color: Color(0xFFFFE5B4),
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
              shadows: [Shadow(blurRadius: 8, color: Colors.black45)],
            ),
          ),
        ],
      ),
    );
  }
}

class DanmakuItem {
  String text;
  double x, y, speed, opacity;
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
          shadows: const [Shadow(blurRadius: 4, color: Colors.black26)],
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
