import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/character_model.dart';
import '../../utils/zodiac_utils.dart';

class BirthdayDetailScreen extends StatefulWidget {
  final Character character;
  const BirthdayDetailScreen({super.key, required this.character});

  @override
  State<BirthdayDetailScreen> createState() => _BirthdayDetailScreenState();
}

class _BirthdayDetailScreenState extends State<BirthdayDetailScreen> {
  late Timer _timer;
  late Duration _timeLeft;

  @override
  void initState() {
    super.initState();
    _calculateTimeLeft();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _calculateTimeLeft();
    });
  }

  void _calculateTimeLeft() {
    final now = DateTime.now();
    final nextBirthday = ZodiacUtils.getNextBirthday(widget.character);

    setState(() {
      _timeLeft = nextBirthday.difference(now);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = _timeLeft.inDays;
    final hours = _timeLeft.inHours % 24;
    final minutes = _timeLeft.inMinutes % 60;
    final seconds = _timeLeft.inSeconds % 60;
    final milliseconds = _timeLeft.inMilliseconds % 1000;

    return Scaffold(
      appBar: AppBar(title: Text(widget.character.name)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar removed
            Text(
              widget.character.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 30),
            const Text('距离生日还有', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                _buildTimeItem(days, '天'),
                _buildTimeItem(hours, '时'),
                _buildTimeItem(minutes, '分'),
                _buildTimeItem(seconds, '秒'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '.$milliseconds',
              style: const TextStyle(fontSize: 30, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeItem(int value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          Text(
            value.toString().padLeft(2, '0'),
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
          ),
          Text(unit, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
