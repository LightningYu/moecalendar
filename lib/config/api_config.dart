import 'package:moecalendar/config/app_info.dart';

/// API 配置常量
class ApiConfig {
  ApiConfig._();

  // ============ Bangumi API ============
  static const String bangumiBaseUrl = 'https://api.bgm.tv';
  static const String bangumiOAuthUrl = 'https://bgm.tv/oauth/authorize';
  static const String bangumiTokenUrl = 'https://bgm.tv/oauth/access_token';
  static const String redirectUri = 'moecalendar://oauth/callback';

  // ============ Secrets (Injected at build time) ============
  // 通过 `flutter build ... --dart-define=BANGUMI_APP_SECRET=...` 注入。
  // 注意：`String.fromEnvironment` 是编译期常量读取方式。
  static const String appId = String.fromEnvironment(
    'BANGUMI_APP_ID',
    defaultValue: 'bgm5232693cf5bc89849',
  );
  static const String appSecret = String.fromEnvironment(
    'BANGUMI_APP_SECRET',
    defaultValue: '',
  );

  // ============ User Agent ============
  static String get userAgent => 'moecalendar/${AppInfo.version} (flutter)';
}
