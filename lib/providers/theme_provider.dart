import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Color _seedColor = Colors.blue;

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final settings = await StorageService().getSettings();
    _themeMode = ThemeMode.values[settings.themeModeIndex];
    _seedColor = Color(settings.seedColorValue);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await StorageService().updateSettings(
      (s) => s.copyWith(themeModeIndex: mode.index),
    );
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    notifyListeners();
    await StorageService().updateSettings(
      (s) => s.copyWith(seedColorValue: color.toARGB32()),
    );
  }
}
