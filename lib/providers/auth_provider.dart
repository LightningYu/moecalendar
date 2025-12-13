import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import '../bangumi/bangumi.dart';
import '../config/api_config.dart';
import '../services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  BangumiUser? _user;
  String? _accessToken;
  String? _refreshToken;
  bool _isLoading = false;

  BangumiUser? get user => _user;
  String? get accessToken => _accessToken;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    final authData = await StorageService().getAuthData();
    if (authData == null) return;

    final userJson = authData['user'] as Map<String, dynamic>?;
    final token = authData['access_token'] as String?;
    final refreshToken = authData['refresh_token'] as String?;

    if (userJson != null && token != null) {
      _user = BangumiUser.fromJson(userJson);
      _accessToken = token;
      _refreshToken = refreshToken;
      notifyListeners();
    }
  }

  Future<void> startLogin() async {
    if (_isLoading) return;

    final Uri authUrl = _buildAuthorizeUrl();
    final String? callbackScheme = Uri.tryParse(ApiConfig.redirectUri)?.scheme;

    if (callbackScheme == null || callbackScheme.isEmpty) {
      debugPrint('Invalid redirect uri: ${ApiConfig.redirectUri}');
      return;
    }

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: callbackScheme,
      );

      final uri = Uri.tryParse(result);
      final code = uri?.queryParameters['code'];
      if (code == null) {
        throw PlatformException(
          code: 'NO_CODE',
          message: 'Bangumi 授权回调缺少 code',
        );
      }
      await _processAuthCode(code);
    } on PlatformException catch (e) {
      debugPrint('FlutterWebAuth2 failed: $e, fallback to external browser');
      await _openExternalAuth(authUrl);
    } catch (e) {
      debugPrint('Start login failed: $e');
      await _openExternalAuth(authUrl);
    }
  }

  Future<void> handleAuthCallback(String code) async {
    await _processAuthCode(code);
  }

  Future<void> _fetchUserInfo() async {
    if (_accessToken == null) return;

    try {
      final dio = Dio();
      final response = await dio.get(
        '${ApiConfig.bangumiBaseUrl}/v0/me',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'User-Agent': ApiConfig.userAgent,
          },
        ),
      );

      if (response.statusCode == 200) {
        _user = BangumiUser.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Fetch User Info Error: $e');
    }
  }

  Uri _buildAuthorizeUrl() {
    return Uri.https('bgm.tv', '/oauth/authorize', {
      'client_id': ApiConfig.appId,
      'response_type': 'code',
      'redirect_uri': ApiConfig.redirectUri,
    });
  }

  Future<void> _openExternalAuth(Uri url) async {
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $url');
    }
  }

  Future<void> _processAuthCode(String code) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final dio = Dio();
      final tokenResponse = await dio.post(
        ApiConfig.bangumiTokenUrl,
        data: {
          'grant_type': 'authorization_code',
          'client_id': ApiConfig.appId,
          'client_secret': ApiConfig.appSecret,
          'code': code,
          'redirect_uri': ApiConfig.redirectUri,
        },
        options: Options(
          headers: {
            'User-Agent': ApiConfig.userAgent,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );

      if (tokenResponse.statusCode == 200) {
        final data = tokenResponse.data;
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];

        await _fetchUserInfo();
        await _saveUser();
      } else {
        throw Exception('Bangumi 授权失败: ${tokenResponse.statusCode}');
      }
    } catch (e) {
      debugPrint('Login Error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveUser() async {
    await StorageService().saveAuthData({
      'user': _user?.toJson(),
      'access_token': _accessToken,
      'refresh_token': _refreshToken,
    });
    debugPrint('User saved: ${_user.toString()}');
  }

  Future<void> logout() async {
    _user = null;
    _accessToken = null;
    _refreshToken = null;

    await StorageService().clearAuthData();
    notifyListeners();
  }
}
