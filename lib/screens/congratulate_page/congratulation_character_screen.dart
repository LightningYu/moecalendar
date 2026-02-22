import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/character_model.dart';
import '../../utils/zodiac_utils.dart';
import '../../config/app_strings.dart';
import '../../config/design_constants.dart';
import '../../widgets/celebration/confetti.dart';
import '../../widgets/celebration/danmaku.dart';

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
          final item = DanmakuGenerator.tryGenerate(
            greetings: AppStrings.birthdayGreetings,
            avoidYStart: 0.35,
            avoidYEnd: 0.65,
          );
          if (item != null) _danmakuList.add(item);
          DanmakuGenerator.updateAll(_danmakuList);
          ConfettiGenerator.updateAll(_particles);
        });
      }
    });

    _particles.addAll(ConfettiGenerator.generateBatch(80));
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
                  color: Colors.orangeAccent.withAlpha(77),
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
