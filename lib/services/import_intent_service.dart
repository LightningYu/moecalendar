import 'dart:async';
import 'package:flutter/services.dart';

/// 处理 Android Intent 传入的 JSON 数据
class ImportIntentService {
  static const _channel = MethodChannel('com.lightningyu.moecalendar/import');

  /// 监听新的 JSON 数据到达
  static final StreamController<String> _jsonController =
      StreamController<String>.broadcast();

  /// JSON 数据流
  static Stream<String> get onJsonReceived => _jsonController.stream;

  /// 初始化：注册 MethodChannel 回调
  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onJsonReceived') {
        final json = call.arguments as String?;
        if (json != null && json.isNotEmpty) {
          _jsonController.add(json);
        }
      }
    });
  }

  /// 获取启动时传入的 JSON（冷启动场景）
  static Future<String?> getInitialJson() async {
    try {
      final result = await _channel.invokeMethod<String>('getInitialJson');
      return result;
    } catch (e) {
      return null;
    }
  }
}
