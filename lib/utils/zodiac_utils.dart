import 'package:lunar/lunar.dart';
import '../models/character_model.dart';

class ZodiacUtils {
  static String getZodiac(int month, int day) {
    const zodiacs = [
      '摩羯座',
      '水瓶座',
      '双鱼座',
      '白羊座',
      '金牛座',
      '双子座',
      '巨蟹座',
      '狮子座',
      '处女座',
      '天秤座',
      '天蝎座',
      '射手座',
      '摩羯座',
    ];
    final dates = [20, 19, 21, 20, 21, 22, 23, 23, 23, 24, 22, 22];
    if (day < dates[month - 1]) {
      return zodiacs[month - 1];
    }
    return zodiacs[month];
  }

  static String getChineseZodiac(int year) {
    // 简单计算，不考虑立春
    const animals = [
      '猴',
      '鸡',
      '狗',
      '猪',
      '鼠',
      '牛',
      '虎',
      '兔',
      '龙',
      '蛇',
      '马',
      '羊',
    ];
    return animals[year % 12];
  }

  static int calculateAge(int birthYear, int birthMonth, int birthDay) {
    final now = DateTime.now();
    int age = now.year - birthYear;
    if (now.month < birthMonth ||
        (now.month == birthMonth && now.day < birthDay)) {
      age--;
    }
    return age;
  }

  static DateTime getNextBirthday(Character character) {
    return _getNextBirthdayInternal(
      character.birthYear ?? DateTime.now().year,
      character.birthMonth,
      character.birthDay,
      character.isLunar,
    );
  }

  // 获取下一个生日的 Solar 日期
  static DateTime _getNextBirthdayInternal(
    int year,
    int month,
    int day,
    bool isLunar,
  ) {
    final now = DateTime.now();
    DateTime birthdayThisYear;

    if (isLunar) {
      Lunar lunarBirthday = Lunar.fromYmd(now.year, month, day);
      Solar solar = lunarBirthday.getSolar();
      birthdayThisYear = DateTime(
        solar.getYear(),
        solar.getMonth(),
        solar.getDay(),
      );

      // 如果今年的农历生日已经过了，取明年
      if (birthdayThisYear.isBefore(DateTime(now.year, now.month, now.day))) {
        lunarBirthday = Lunar.fromYmd(now.year + 1, month, day);
        solar = lunarBirthday.getSolar();
        return DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
      }
      return birthdayThisYear;
    } else {
      birthdayThisYear = DateTime(now.year, month, day);
      if (birthdayThisYear.isBefore(DateTime(now.year, now.month, now.day))) {
        return DateTime(now.year + 1, month, day);
      }
      return birthdayThisYear;
    }
  }

  static bool isBirthdayToday(int month, int day, bool isLunar) {
    final now = DateTime.now();
    if (!isLunar) {
      return now.month == month && now.day == day;
    } else {
      final lunar = Lunar.fromDate(now);
      return lunar.getMonth() == month && lunar.getDay() == day;
    }
  }
}
