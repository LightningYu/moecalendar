import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../models/character_model.dart';
import '../models/app_settings.dart';
import '../utils/path_manager.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _settingsFileName = 'settings.json';
  static const String _authFileName = 'auth.json';

  Future<void> init() async {
    await PathManager().init();
    await PathManager().ensureImagesDirExists();
  }

  // ============ Characters ============

  Future<List<Character>> getCharacters() async {
    try {
      final file = File(PathManager().dataFilePath);
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => Character.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error reading characters: $e');
      return [];
    }
  }

  Future<void> saveAll(List<Character> characters) async {
    try {
      final file = File(PathManager().dataFilePath);
      final jsonList = characters.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving characters: $e');
    }
  }

  Future<void> saveCharacter(Character character) async {
    final characters = await getCharacters();
    final index = characters.indexWhere((c) => c.id == character.id);
    if (index >= 0) {
      characters[index] = character;
    } else {
      characters.add(character);
    }
    await saveAll(characters);
  }

  Future<void> deleteCharacter(String id) async {
    final characters = await getCharacters();
    characters.removeWhere((c) => c.id == id);
    await saveAll(characters);
  }

  // ============ App Settings ============

  String get _settingsPath =>
      path.join(PathManager().documentsPath, _settingsFileName);

  Future<AppSettings> getSettings() async {
    try {
      final file = File(_settingsPath);
      if (!await file.exists()) return const AppSettings();
      final content = await file.readAsString();
      if (content.isEmpty) return const AppSettings();
      return AppSettings.fromJson(jsonDecode(content));
    } catch (e) {
      debugPrint('Error reading settings: $e');
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    try {
      final file = File(_settingsPath);
      await file.writeAsString(jsonEncode(settings.toJson()));
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Future<void> updateSettings(AppSettings Function(AppSettings) update) async {
    final current = await getSettings();
    await saveSettings(update(current));
  }

  // ============ Auth Data ============

  String get _authPath => path.join(PathManager().documentsPath, _authFileName);

  Future<Map<String, dynamic>?> getAuthData() async {
    try {
      final file = File(_authPath);
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.isEmpty) return null;
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error reading auth data: $e');
      return null;
    }
  }

  Future<void> saveAuthData(Map<String, dynamic> data) async {
    try {
      final file = File(_authPath);
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving auth data: $e');
    }
  }

  Future<void> clearAuthData() async {
    try {
      final file = File(_authPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error clearing auth data: $e');
    }
  }
}
