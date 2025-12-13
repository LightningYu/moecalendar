import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart';
import '../models/character_model.dart';
import '../utils/zodiac_utils.dart';

/// 日历服务 - 用于将生日事件添加到系统日历
class CalendarService {
  CalendarService._();
  static final CalendarService instance = CalendarService._();

  /// 添加角色生日到系统日历
  ///
  /// 通过 Android Intent 打开系统日历应用,预填生日信息
  /// 用户可以选择保存或取消
  Future<bool> addBirthdayToCalendar(Character character) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      // 计算下一个生日日期
      final nextBirthday = ZodiacUtils.getNextBirthday(character);

      // 设置为全天事件 (0:00 - 23:59)
      final startTime = DateTime(
        nextBirthday.year,
        nextBirthday.month,
        nextBirthday.day,
        0,
        0,
      );
      final endTime = DateTime(
        nextBirthday.year,
        nextBirthday.month,
        nextBirthday.day,
        23,
        59,
      );

      // 构建事件描述
      final description = _buildDescription(character);

      // 构建事件标题
      final title = character.isSelf ? '🎂 我的生日' : '🎂 ${character.name} 的生日';

      // 创建 Android Intent
      final intent = AndroidIntent(
        action: 'android.intent.action.INSERT',
        data: 'content://com.android.calendar/events',
        arguments: <String, dynamic>{
          'title': title,
          'description': description,
          'beginTime': startTime.millisecondsSinceEpoch,
          'endTime': endTime.millisecondsSinceEpoch,
          'allDay': true,
          // 每年重复 (RRULE 格式)
          'rrule': 'FREQ=YEARLY',
        },
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );

      await intent.launch();
      return true;
    } catch (e) {
      debugPrint('添加生日到日历失败: $e');
      return false;
    }
  }

  /// 批量添加所有角色生日到日历
  ///
  /// 注意: 每次调用都会打开系统日历,所以这个方法会逐个打开
  /// 建议在 UI 层提示用户
  Future<void> addAllBirthdaysToCalendar(List<Character> characters) async {
    for (final character in characters) {
      await addBirthdayToCalendar(character);
      // 等待用户完成操作
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  /// 构建事件描述
  String _buildDescription(Character character) {
    final parts = <String>[];

    // 添加日期信息
    final dateStr = '${character.birthMonth}月${character.birthDay}日';
    if (character.isLunar) {
      parts.add('农历: $dateStr');
    } else {
      parts.add('公历: $dateStr');
    }

    // 如果是 Bangumi 角色,添加来源信息
    if (character is BangumiCharacter) {
      parts.add('来源: Bangumi');
      parts.add('Bangumi ID: ${character.bangumiId}');
    }

    parts.add('');
    parts.add('来自「生日追踪」应用');

    return parts.join('\n');
  }
}
