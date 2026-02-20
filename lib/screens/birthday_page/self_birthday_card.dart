import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/character_model.dart';
import '../../config/routes/app_routes.dart';
import '../../config/design_constants.dart';
import '../../utils/zodiac_utils.dart';

class SelfBirthdayCard extends StatefulWidget {
  final Character character;
  const SelfBirthdayCard({super.key, required this.character});

  @override
  State<SelfBirthdayCard> createState() => _SelfBirthdayCardState();
}

class _SelfBirthdayCardState extends State<SelfBirthdayCard> {
  late Timer _timer;
  double _preciseAge = 0.0;
  bool _isBirthday = false;

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
      if (mounted) {
        _updateTime();
      }
    });
  }

  void _updateTime() {
    if (widget.character.birthYear == null) return;

    final now = DateTime.now();
    // 检查今天是否是生日
    final isBirthdayToday = ZodiacUtils.isBirthdayToday(
      widget.character.birthMonth,
      widget.character.birthDay,
      widget.character.isLunar,
    );

    final birthDate = DateTime(
      widget.character.birthYear!,
      widget.character.birthMonth,
      widget.character.birthDay,
    );

    final duration = now.difference(birthDate);
    final totalDays = duration.inDays;
    const daysPerYear = 365.2425;

    // 粗略计算岁数
    final age = totalDays / daysPerYear;

    final totalSecondsLived = duration.inSeconds;

    setState(() {
      _isBirthday = isBirthdayToday;
      // 通过毫秒数使得岁数更新更连续 平滑
      _preciseAge =
          age + (duration.inMilliseconds % 86400000) / 86400000 / daysPerYear;
      _totalYears = (totalDays / daysPerYear).floor();
      _totalMonths = (totalDays / 30.4375).floor();
      _totalWeeks = totalDays ~/ 7;
      _totalDays = totalDays;
      _totalHours = totalSecondsLived ~/ 3600;
      _totalMinutes = totalSecondsLived ~/ 60;
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cake_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: DesignConstants.spacing),
            const Text('请设置出生年份以查看人生进度'),
          ],
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesignConstants.spacing),
      child: Column(
        children: [
          // 顶部显示精准年龄
          _buildAgeCard(context),
          const SizedBox(height: DesignConstants.spacingLg),

          // 在线时长标题
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: DesignConstants.spacingSm),
              Text(
                '你在地球上已逗留',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: DesignConstants.spacing),

          // 核心统计网格
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.6,
            mainAxisSpacing: DesignConstants.spacing,
            crossAxisSpacing: DesignConstants.spacing,
            children: [
              _buildStatTile(context, '岁', _totalYears, Icons.event),
              _buildStatTile(context, '月', _totalMonths, Icons.calendar_month),
              _buildStatTile(context, '周', _totalWeeks, Icons.view_week),
              _buildStatTile(context, '天', _totalDays, Icons.today),
              _buildStatTile(context, '小时', _totalHours, Icons.schedule),
              _buildStatTile(
                context,
                '分钟',
                _totalMinutes,
                Icons.timer_outlined,
              ),
            ],
          ),

          const SizedBox(height: DesignConstants.spacingXl),

          // 底部操作
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                context.push(AppRoutes.congratulate, extra: widget.character);
              },
              icon: Icon(
                _isBirthday ? Icons.celebration : Icons.auto_stories_outlined,
              ),
              label: Text(
                _isBirthday ? '领取生日惊喜' : '查看人生日志',
                style: const TextStyle(fontSize: 16),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _isBirthday
                    ? colorScheme.errorContainer
                    : colorScheme.primary,
                foregroundColor: _isBirthday
                    ? colorScheme.onErrorContainer
                    : colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignConstants.radiusLg),
                ),
              ),
            ),
          ),
          const SizedBox(height: DesignConstants.spacingXl),
        ],
      ),
    );
  }

  Widget _buildAgeCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignConstants.radiusLg),
        side: BorderSide(color: colorScheme.primary.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignConstants.spacingLg),
        child: Column(
          children: [
            Text(
              '你已经',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: DesignConstants.spacingSm),
            FittedBox(
              child: Text(
                _preciseAge.toStringAsFixed(8),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  letterSpacing: -1,
                ),
              ),
            ),
            const SizedBox(height: DesignConstants.spacingSm),
            Text(
              '岁了',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(
    BuildContext context,
    String label,
    int value,
    IconData icon,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(DesignConstants.spacing),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(DesignConstants.radiusMd),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(DesignConstants.spacingXs),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: colorScheme.primary),
          ),
          const SizedBox(width: DesignConstants.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value.toString(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
