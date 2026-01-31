import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/character_model.dart';
import '../../config/routes/app_routes.dart';
import '../../config/design_constants.dart';

class SelfBirthdayCard extends StatefulWidget {
  final Character character;
  const SelfBirthdayCard({super.key, required this.character});

  @override
  State<SelfBirthdayCard> createState() => _SelfBirthdayCardState();
}

class _SelfBirthdayCardState extends State<SelfBirthdayCard> {
  late Timer _timer;
  double _preciseAge = 0.0;

  // 直接存储计算结果，不依赖 Duration
  int _totalYears = 0;
  int _totalMonths = 0;
  int _totalWeeks = 0;
  int _totalDays = 0;
  int _totalHours = 0;
  int _totalMinutes = 0;

  @override
  void initState() {
    super.initState();
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

    final totalDays = now.difference(birthDate).inDays;
    const daysPerYear = 365.2425;
    final age = totalDays / daysPerYear;

    // 累计换算各单位
    final totalWeeks = totalDays ~/ 7;
    final totalMonths = (totalDays / 30.4375).floor();
    final totalYears = (totalDays / daysPerYear).floor();

    // 时间部分：从午夜到现在的秒数 + 总天数的秒数
    final secondsSinceMidnight = now.hour * 3600 + now.minute * 60 + now.second;
    final totalSecondsLived = totalDays * 86400 + secondsSinceMidnight;
    final totalHours = totalSecondsLived ~/ 3600;
    final totalMinutes = totalSecondsLived ~/ 60;

    setState(() {
      _preciseAge = age + (secondsSinceMidnight / 86400 / daysPerYear);
      _totalYears = totalYears;
      _totalMonths = totalMonths;
      _totalWeeks = totalWeeks;
      _totalDays = totalDays;
      _totalHours = totalHours;
      _totalMinutes = totalMinutes;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.character.birthYear == null) {
      return const Center(child: Text('请设置出生年份以查看详细数据'));
    }

    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '你已经',
              style: TextStyle(
                fontSize: 20,
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _preciseAge.toStringAsFixed(6),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              '岁了',
              style: TextStyle(
                fontSize: 20,
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              '在线时长',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: DesignConstants.spacing * 1.25),
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: DesignConstants.spacingXl,
              ),
              padding: const EdgeInsets.all(DesignConstants.spacing),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(DesignConstants.radiusLg),
              ),
              child: Column(
                children: [
                  _buildTableRow(
                    3,
                    ['年', '月', '周'],
                    [_totalYears, _totalMonths, _totalWeeks],
                  ),
                  const Divider(height: 30),
                  _buildTableRow(
                    3,
                    ['天', '小时', '分钟'],
                    [_totalDays, _totalHours, _totalMinutes],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                context.push(AppRoutes.congratulate, extra: widget.character);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('人生日志', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow(int length, List<String> labels, List<int> values) {
    return Row(
      children: List.generate(length, (index) {
        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                labels[index],
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).hintColor,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  values[index].toString(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
