/// 应用信息常量
class AppInfo {
  AppInfo._();

  // ============ 应用基本信息 ============
  static const String name = '萌历';
  static const String packageName = 'com.lightningyu.moecalendar';
  static const String version = '1.0.0';

  // ============ 存储相关 ============
  static const String dataFileName = 'characters.json';
  static const String imageFolderName = 'images';

  // ============ UI 常量 ============
  static const double kCharacterListItemHeight = 80.0;

  // ============ 外部链接 ============
  static const String githubUrl = 'https://github.com/LightningYu/moecalendar';
  static const String bangumiDevUrl = 'https://bgm.tv/dev/app';
  static const String bilibiliUrl = 'https://space.bilibili.com/1938216007';

  // ============ 应用描述 ============
  static const String appDescription = '''
  一个简洁优雅的生日管理应用
  支持农历、阳历生日提醒
  集成 Bangumi 角色生日数据
  ''';

  // ============ 开发者信息 ============
  static const String developerName = 'LightningYu';
  static const String developerBio = '普普通通高中生';

  // ============ 开源许可 ============
  static const String license = 'MIT License';
  static const String copyright = '© 2024 LightningYu';
}
