import 'package:moecalendar/config/app_info.dart';

/// API 配置常量
class ApiConfig {
  ApiConfig._();

  // ============ Bangumi API ============
  static const String bangumiBaseUrl = 'https://api.bgm.tv';
  static const String bangumiOAuthUrl = 'https://bgm.tv/oauth/authorize';
  static const String bangumiTokenUrl = 'https://bgm.tv/oauth/access_token';
  static const String redirectUri = 'moecalendar://oauth/callback';

  // ============ Secrets (Hardcoded) ============
  static const String appId = 'bgm5232693cf5bc89849';
  static const String appSecret = '33c92efd79fe113732b094495bce3ade';

  // ============ User Agent ============
  static String get userAgent => 'moecalendar/${AppInfo.version} (flutter)';
}
