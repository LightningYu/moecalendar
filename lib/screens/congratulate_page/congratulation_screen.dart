import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/character_model.dart';
import '../../utils/zodiac_utils.dart';
import '../../config/app_strings.dart';
import '../../widgets/celebration/confetti.dart';
import '../../widgets/celebration/danmaku.dart';

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

    _particles.addAll(ConfettiGenerator.generateBatch(60));

    _celebrationController.addListener(() {
      if (!mounted) return;
      setState(() {
        ConfettiGenerator.updateAll(_particles);
        if (_isBirthday) {
          final item = DanmakuGenerator.tryGenerate(
            greetings: AppStrings.birthdayGreetings,
          );
          if (item != null) _danmakuList.add(item);
          DanmakuGenerator.updateAll(_danmakuList);
        }
      });
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

    final isBirthdayToday = ZodiacUtils.isBirthdayToday(
      widget.character.birthMonth,
      widget.character.birthDay,
      widget.character.isLunar,
    );

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
