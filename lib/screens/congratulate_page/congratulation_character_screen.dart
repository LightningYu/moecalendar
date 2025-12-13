import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/character_model.dart';
import '../../utils/zodiac_utils.dart';

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
  int _countdown = 15;
  Timer? _countdownTimer;
  bool _isPhase1 = true;

  // Phase 2: Celebration
  late AnimationController _danmakuController;
  final List<DanmakuItem> _danmakuList = [];
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
      duration: const Duration(seconds: 10),
    )..repeat();

    _danmakuController.addListener(() {
      if (!mounted) return;
      if (!_isPhase1) {
        setState(() {
          _updateDanmaku();
        });
      }
    });
  }

  void _checkPhase() {
    if (widget.characters.isEmpty) {
      setState(() => _isPhase1 = false);
      return;
    }

    final now = DateTime.now();
    final nextBirthday = ZodiacUtils.getNextBirthday(widget.characters.first);
    final diff = nextBirthday.difference(now).inSeconds;

    // If within 20 seconds of birthday, start countdown
    if (diff > 0 && diff <= 20) {
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
    if (_random.nextInt(100) < 5) {
      // 5% chance per frame
      _danmakuList.add(
        DanmakuItem(
          text: _birthdayGreetings[_random.nextInt(_birthdayGreetings.length)],
          x: 1.2,
          y: 0.1 + _random.nextDouble() * 0.8,
          speed: 0.002 + _random.nextDouble() * 0.003,
          color: Colors.primaries[_random.nextInt(Colors.primaries.length)],
          fontSize: 20 + _random.nextDouble() * 20,
        ),
      );
    }

    for (var item in _danmakuList) {
      item.x -= item.speed;
    }
    _danmakuList.removeWhere((item) => item.x < -0.5);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _danmakuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A237E), Color(0xFF000000)],
              ),
            ),
          ),

          // Phase 1: Countdown
          if (_isPhase1)
            Center(
              child: Text(
                '$_countdown',
                style: const TextStyle(
                  fontSize: 120,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

          // Phase 2: Celebration
          if (!_isPhase1) ...[
            // Danmaku
            CustomPaint(
              painter: DanmakuPainter(_danmakuList),
              size: Size.infinite,
            ),
            // Text
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: widget.characters.map((c) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: _buildCharacterGreeting(c),
                  );
                }).toList(),
              ),
            ),
          ],

          // Back Button
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterGreeting(Character c) {
    // Logic:
    // "生日快乐" \n "[Name]"
    // Else: "生日快乐" \n "[Name]"

    return Column(
      children: [
        const Text(
          '生日快乐',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(blurRadius: 10, color: Colors.pink, offset: Offset(0, 0)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          c.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class DanmakuItem {
  String text;
  double x;
  double y;
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
