import 'package:flutter/material.dart';
import 'storage_service.dart';

/// 权限管理服务（引导流程状态）
class PermissionService {
  /// 检查是否已完成引导
  static Future<bool> isOnboardingCompleted() async {
    final settings = await StorageService().getSettings();
    return settings.onboardingCompleted;
  }

  /// 标记引导完成
  static Future<void> setOnboardingCompleted() async {
    await StorageService().updateSettings(
      (s) => s.copyWith(onboardingCompleted: true),
    );
  }

  /// 检查是否已设置自己的生日
  static Future<bool> isSelfBirthdaySet() async {
    final settings = await StorageService().getSettings();
    return settings.selfBirthdaySet;
  }

  /// 标记已设置自己的生日
  static Future<void> setSelfBirthdaySet(bool value) async {
    await StorageService().updateSettings(
      (s) => s.copyWith(selfBirthdaySet: value),
    );
  }

  /// 显示权限说明对话框
  static Future<bool> showPermissionExplanationDialog(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(icon, size: 48),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('授权'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
