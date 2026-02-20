import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../models/character_model.dart';
import '../services/storage_service.dart';
import '../utils/path_manager.dart';

/// 导出数据中的 Bangumi 角色条目（仅存 bangumiId）
class BangumiExportEntry {
  final int bangumiId;

  BangumiExportEntry({required this.bangumiId});

  Map<String, dynamic> toJson() => {'type': 'bangumi', 'bangumiId': bangumiId};

  factory BangumiExportEntry.fromJson(Map<String, dynamic> json) {
    return BangumiExportEntry(bangumiId: json['bangumiId'] as int);
  }
}

/// 导入解析结果
class ImportParseResult {
  final int version;

  /// 完整的手动角色数据
  final List<ManualCharacter> manualCharacters;

  /// 完整的 Bangumi 角色数据（旧格式兼容）
  final List<BangumiCharacter> fullBangumiCharacters;

  /// 仅含 bangumiId 的条目（新格式）
  final List<int> bangumiIds;

  ImportParseResult({
    required this.version,
    required this.manualCharacters,
    required this.fullBangumiCharacters,
    required this.bangumiIds,
  });

  int get totalCount =>
      manualCharacters.length +
      fullBangumiCharacters.length +
      bangumiIds.length;

  bool get isEmpty => totalCount == 0;

  /// 获取所有完整角色（手动 + 旧格式 bangumi）
  List<Character> get allFullCharacters => [
    ...manualCharacters,
    ...fullBangumiCharacters,
  ];
}

/// 数据同步服务：导出 / 导入应用数据
class DataSyncService {
  static final DataSyncService _instance = DataSyncService._internal();
  factory DataSyncService() => _instance;
  DataSyncService._internal();

  final StorageService _storageService = StorageService();

  // ============ 导出数据版本号 ============
  static const int _exportVersion = 2;

  /// 导出所有角色数据为 JSON 字符串
  ///
  /// 新格式 v2：
  /// - ManualCharacter 完整导出
  /// - BangumiCharacter 只导出 bangumiId
  Future<String> exportToJson() async {
    final characters = await _storageService.getCharacters();

    final manualList = <Map<String, dynamic>>[];
    final bangumiIdList = <Map<String, dynamic>>[];

    for (final c in characters) {
      if (c is BangumiCharacter) {
        bangumiIdList.add(BangumiExportEntry(bangumiId: c.bangumiId).toJson());
      } else {
        manualList.add(c.toJson());
      }
    }

    final exportData = {
      'version': _exportVersion,
      'exportTime': DateTime.now().toIso8601String(),
      'appName': 'moecalendar',
      'characterCount': characters.length,
      'characters': manualList,
      'bangumiCharacters': bangumiIdList,
    };

    final encoder = const JsonEncoder.withIndent('  ');
    return encoder.convert(exportData);
  }

  /// 生成导出文件名（含时间戳）
  String generateExportFileName() {
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    return 'moecalendar_backup_$timestamp.json';
  }

  /// 导出数据为 UTF-8 字节（供 saveFile / share 使用）
  Future<({String fileName, Uint8List bytes})> exportToBytes() async {
    final json = await exportToJson();
    final bytes = Uint8List.fromList(utf8.encode(json));
    return (fileName: generateExportFileName(), bytes: bytes);
  }

  /// 写出到临时文件并返回路径（供 share_plus 使用）
  Future<String> exportToTempFile() async {
    final json = await exportToJson();
    final fileName = generateExportFileName();
    final filePath = path.join(PathManager().cachePath, fileName);
    final file = File(filePath);
    await file.writeAsString(json, flush: true);
    return filePath;
  }

  /// 从 JSON 字符串解析导入数据
  ///
  /// 自动兼容多种格式：
  /// - v2 格式：`{ characters: [手动], bangumiCharacters: [{bangumiId}] }`
  /// - v1 格式：`{ characters: [所有角色完整数据] }`
  /// - 旧格式：直接是角色数组 `[...]`
  ImportParseResult? parseJson(String jsonStr) {
    try {
      final dynamic decoded = jsonDecode(jsonStr);

      if (decoded is Map<String, dynamic>) {
        final version = decoded['version'] as int? ?? 1;

        if (version >= 2) {
          return _parseV2(decoded, version);
        } else {
          return _parseV1(decoded, version);
        }
      } else if (decoded is List) {
        // 旧格式（直接是角色数组）
        return _parseLegacyArray(decoded);
      }

      return null;
    } catch (e) {
      debugPrint('JSON 解析失败: $e');
      return null;
    }
  }

  /// 解析 v2 格式
  ImportParseResult _parseV2(Map<String, dynamic> data, int version) {
    final manualCharacters = <ManualCharacter>[];
    final fullBangumiCharacters = <BangumiCharacter>[];
    final bangumiIds = <int>[];

    // 解析手动角色
    final charList = data['characters'] as List? ?? [];
    for (final item in charList) {
      try {
        final c = Character.fromJson(item as Map<String, dynamic>);
        if (c is ManualCharacter) {
          manualCharacters.add(c);
        } else if (c is BangumiCharacter) {
          // v2 的 characters 字段理论上只有手动角色，
          // 但为容错也接受完整 bangumi 角色
          fullBangumiCharacters.add(c);
        }
      } catch (e) {
        debugPrint('跳过无法解析的角色: $e');
      }
    }

    // 解析 bangumiId 列表
    final bangumiList = data['bangumiCharacters'] as List? ?? [];
    for (final item in bangumiList) {
      try {
        if (item is Map<String, dynamic>) {
          final bid = item['bangumiId'] as int?;
          if (bid != null) {
            bangumiIds.add(bid);
          }
        }
      } catch (e) {
        debugPrint('跳过无法解析的 bangumiId: $e');
      }
    }

    return ImportParseResult(
      version: version,
      manualCharacters: manualCharacters,
      fullBangumiCharacters: fullBangumiCharacters,
      bangumiIds: bangumiIds,
    );
  }

  /// 解析 v1 格式
  ImportParseResult _parseV1(Map<String, dynamic> data, int version) {
    final manualCharacters = <ManualCharacter>[];
    final fullBangumiCharacters = <BangumiCharacter>[];

    final List<dynamic> list = data['characters'] ?? [];
    for (final item in list) {
      try {
        final c = Character.fromJson(item as Map<String, dynamic>);
        if (c is ManualCharacter) {
          manualCharacters.add(c);
        } else if (c is BangumiCharacter) {
          fullBangumiCharacters.add(c);
        }
      } catch (e) {
        debugPrint('跳过无法解析的角色: $e');
      }
    }

    return ImportParseResult(
      version: version,
      manualCharacters: manualCharacters,
      fullBangumiCharacters: fullBangumiCharacters,
      bangumiIds: [],
    );
  }

  /// 解析旧格式（直接是角色数组）
  ImportParseResult _parseLegacyArray(List<dynamic> list) {
    final manualCharacters = <ManualCharacter>[];
    final fullBangumiCharacters = <BangumiCharacter>[];

    for (final item in list) {
      try {
        final c = Character.fromJson(item as Map<String, dynamic>);
        if (c is ManualCharacter) {
          manualCharacters.add(c);
        } else if (c is BangumiCharacter) {
          fullBangumiCharacters.add(c);
        }
      } catch (e) {
        debugPrint('跳过无法解析的角色: $e');
      }
    }

    return ImportParseResult(
      version: 0,
      manualCharacters: manualCharacters,
      fullBangumiCharacters: fullBangumiCharacters,
      bangumiIds: [],
    );
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
