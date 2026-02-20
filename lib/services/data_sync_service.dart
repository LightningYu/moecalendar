import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../models/character_model.dart';
import '../services/storage_service.dart';
import '../utils/path_manager.dart';

/// 数据同步服务：导出 / 导入应用数据
class DataSyncService {
  static final DataSyncService _instance = DataSyncService._internal();
  factory DataSyncService() => _instance;
  DataSyncService._internal();

  final StorageService _storageService = StorageService();

  // ============ 导出数据版本号 ============
  static const int _exportVersion = 1;

  /// 导出所有角色数据为 JSON 字符串
  Future<String> exportToJson() async {
    final characters = await _storageService.getCharacters();
    final exportData = {
      'version': _exportVersion,
      'exportTime': DateTime.now().toIso8601String(),
      'appName': 'moecalendar',
      'characterCount': characters.length,
      'characters': characters.map((c) => c.toJson()).toList(),
    };
    // 使用缩进以便人类阅读
    final encoder = const JsonEncoder.withIndent('  ');
    return encoder.convert(exportData);
  }

  /// 导出到文件，返回文件路径
  Future<String> exportToFile() async {
    final json = await exportToJson();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final fileName = 'moecalendar_backup_$timestamp.json';
    final filePath = path.join(PathManager().documentsPath, fileName);
    final file = File(filePath);
    await file.writeAsString(json);
    return filePath;
  }

  /// 从 JSON 字符串解析角色列表
  ///
  /// 自动兼容新旧格式：
  /// - 新格式：`{ version, characters: [...] }`
  /// - 旧格式：直接是角色数组 `[...]`
  ///
  /// 返回 null 表示解析失败
  ({List<Character> characters, int version})? parseJson(String jsonStr) {
    try {
      final dynamic decoded = jsonDecode(jsonStr);

      if (decoded is Map<String, dynamic>) {
        // 新格式
        final version = decoded['version'] as int? ?? 1;
        final List<dynamic> list = decoded['characters'] ?? [];
        final characters = <Character>[];
        for (final item in list) {
          try {
            characters.add(Character.fromJson(item as Map<String, dynamic>));
          } catch (e) {
            debugPrint('跳过无法解析的角色: $e');
          }
        }
        return (characters: characters, version: version);
      } else if (decoded is List) {
        // 旧格式（直接是角色数组）
        final characters = <Character>[];
        for (final item in decoded) {
          try {
            characters.add(Character.fromJson(item as Map<String, dynamic>));
          } catch (e) {
            debugPrint('跳过无法解析的角色: $e');
          }
        }
        return (characters: characters, version: 0);
      }

      return null;
    } catch (e) {
      debugPrint('JSON 解析失败: $e');
      return null;
    }
  }

  /// 从文件路径读取 JSON
  Future<String?> readFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (e) {
      debugPrint('读取文件失败: $e');
      return null;
    }
  }
}
