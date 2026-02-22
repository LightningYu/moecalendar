import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../models/character_model.dart';
import '../services/storage_service.dart';
import '../bangumi/bangumi.dart';

class CharacterProvider extends ChangeNotifier {
  CharacterProvider() {
    _init();
  }

  final StorageService _storageService = StorageService();

  List<Character> _characters = [];

  /// 用于等待初始化完成的 Completer，防止写操作与 _loadData 发生竞态
  final Completer<void> _initCompleter = Completer<void>();

  /// 等待初始化完成的 Future
  Future<void> get initialized => _initCompleter.future;

  UnmodifiableListView<Character> get characters =>
      UnmodifiableListView(_characters);

  List<ManualCharacter> get manualCharacters => _characters
      .whereType<ManualCharacter>()
      .where((c) => !c.isSelf)
      .toList(growable: false);

  List<BangumiCharacter> get bangumiCharacters =>
      _characters.whereType<BangumiCharacter>().toList(growable: false);

  ManualCharacter? get selfCharacter {
    try {
      return _characters.whereType<ManualCharacter>().firstWhere(
        (c) => c.isSelf,
      );
    } catch (_) {
      return null;
    }
  }

  // ============ 批量添加进度 ============

  /// 当前是否在批量添加
  bool _isBatchAdding = false;
  bool get isBatchAdding => _isBatchAdding;

  /// 批量添加进度: 已处理 / 总量
  int _batchTotal = 0;
  int _batchDone = 0;
  int get batchTotal => _batchTotal;
  int get batchDone => _batchDone;

  Future<void> _init() async {
    await _loadData();
    await _migrateAvatarColors();
    _initCompleter.complete();
  }

  /// 新增角色（内存优先，再写磁盘）
  Future<void> addCharacter(Character character) async {
    await initialized;
    _characters.add(character);
    notifyListeners();
    await _storageService.saveAll(_characters);
  }

  /// 更新角色
  Future<void> updateCharacter(Character character) async {
    await initialized;
    final index = _characters.indexWhere((c) => c.id == character.id);
    if (index >= 0) {
      _characters[index] = character;
    } else {
      _characters.add(character);
    }
    notifyListeners();
    await _storageService.saveAll(_characters);
  }

  /// 删除角色
  Future<void> deleteCharacter(String id) async {
    await initialized;
    _characters.removeWhere((c) => c.id == id);
    notifyListeners();
    await _storageService.saveAll(_characters);
  }

  /// 新增或更新自己的生日信息
  Future<ManualCharacter> upsertSelfCharacter({
    required DateTime birthday,
    required bool isLunar,
    String? displayName,
  }) async {
    // 等待初始化完成，防止 _loadData 在写入后覆盖内存数据（首次 onboarding 竞态问题）
    await initialized;
    final existing = selfCharacter;
    final ManualCharacter updated =
        existing?.copyWith(
          birthYear: birthday.year,
          birthMonth: birthday.month,
          birthDay: birthday.day,
          isLunar: isLunar,
          name: displayName ?? existing.name,
          isSelf: true,
        ) ??
        ManualCharacter(
          id: 'self_${DateTime.now().millisecondsSinceEpoch}',
          notificationId: DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF,
          name: displayName ?? existing?.name ?? '你',
          birthYear: birthday.year,
          birthMonth: birthday.month,
          birthDay: birthday.day,
          notify: false,
          isLunar: isLunar,
          isSelf: true,
        );

    final index = _characters.indexWhere((c) => c.id == updated.id);
    if (index >= 0) {
      _characters[index] = updated;
    } else {
      _characters.add(updated);
    }
    notifyListeners();
    await _storageService.saveAll(_characters);
    return updated;
  }

  /// 刷新数据
  Future<void> refresh() async {
    await _loadData();
  }

  /// 批量添加 Bangumi 角色（逐个拉取详情后入库）
  ///
  /// 图片完全由 CachedNetworkImage 在展示时自动缓存，无需本地下载。
  Future<void> addBangumiCharactersAsync(
    List<BangumiCharacterDto> dtoList,
  ) async {
    if (dtoList.isEmpty) return;

    _isBatchAdding = true;
    _batchTotal = dtoList.length;
    _batchDone = 0;
    notifyListeners();

    final bangumiService = BangumiService();
    final existingBids = _characters
        .whereType<BangumiCharacter>()
        .map((c) => c.bangumiId)
        .toSet();

    try {
      for (final dto in dtoList) {
        // 跳过已存在的
        if (existingBids.contains(dto.id)) {
          _batchDone++;
          notifyListeners();
          continue;
        }

        // 拉取详情（获取完整生日信息）
        BangumiCharacterDto? detail;
        try {
          detail = await bangumiService.getCharacterDetail(dto.id);
        } catch (e) {
          debugPrint('拉取角色 ${dto.id} 详情失败: $e');
        }

        final src = detail ?? dto;
        if (!src.hasBirthday) {
          _batchDone++;
          notifyListeners();
          continue;
        }

        final now = DateTime.now().millisecondsSinceEpoch;
        final id = '${now}_${src.id}';
        final notificationId = now & 0x7FFFFFFF;

        final newChar = BangumiCharacter(
          id: id,
          notificationId: notificationId,
          name: src.displayName,
          birthYear: src.birthYear,
          birthMonth: src.birthMon!,
          birthDay: src.birthDay!,
          notify: true,
          avatarPath: src.avatarLargeUrl,
          bangumiId: src.id,
          originalData: src.originalData,
          gridAvatarPath: src.avatarGridUrl,
          largeAvatarPath: src.avatarLargeUrl,
          avatarColor: Character.generateAvatarColor(),
        );

        _characters.add(newChar);
        existingBids.add(src.id);
        _batchDone++;
        notifyListeners();

        // 每次写全量，保证磁盘与内存一致（含 self 等其他角色）
        await _storageService.saveAll(_characters);
      }
    } finally {
      _isBatchAdding = false;
      notifyListeners();
    }
  }

  /// 添加单个在线 Bangumi 角色
  Future<BangumiCharacter?> addBangumiCharacterFromDto(
    BangumiCharacterDto dto,
  ) async {
    if (!dto.hasBirthday) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = '${now}_${dto.id}';
    final notificationId = now & 0x7FFFFFFF;

    final newChar = BangumiCharacter(
      id: id,
      notificationId: notificationId,
      name: dto.displayName,
      birthYear: dto.birthYear,
      birthMonth: dto.birthMon!,
      birthDay: dto.birthDay!,
      notify: true,
      avatarPath: dto.avatarLargeUrl,
      bangumiId: dto.id,
      originalData: dto.originalData,
      gridAvatarPath: dto.avatarGridUrl,
      largeAvatarPath: dto.avatarLargeUrl,
      avatarColor: Character.generateAvatarColor(),
    );

    _characters.add(newChar);
    notifyListeners();
    await _storageService.saveAll(_characters);
    return newChar;
  }

  /// 刷新本地 Bangumi 角色数据（重新拉取 API）
  Future<BangumiCharacter?> refreshBangumiCharacter(
    BangumiCharacter bangumiChar,
  ) async {
    final bangumiService = BangumiService();
    final dto = await bangumiService.getCharacterDetail(bangumiChar.bangumiId);
    if (dto == null) return null;

    final updated = bangumiChar.copyWith(
      name: dto.displayName,
      birthYear: dto.birthYear,
      birthMonth: dto.birthMon ?? bangumiChar.birthMonth,
      birthDay: dto.birthDay ?? bangumiChar.birthDay,
      originalData: dto.originalData,
      gridAvatarPath: dto.avatarGridUrl,
      largeAvatarPath: dto.avatarLargeUrl,
      avatarPath: dto.avatarLargeUrl,
    );

    final index = _characters.indexWhere((c) => c.id == updated.id);
    if (index >= 0) {
      _characters[index] = updated;
    }
    notifyListeners();
    await _storageService.saveAll(_characters);
    return updated;
  }

  Future<void> _loadData() async {
    _characters = await _storageService.getCharacters();
    await _repairSelfFlag();
    notifyListeners();
  }

  /// 迁移旧数据：为缺少 avatarColor 的角色自动生成颜色并持久化
  Future<void> _migrateAvatarColors() async {
    bool needsSave = false;
    for (int i = 0; i < _characters.length; i++) {
      final c = _characters[i];
      if (c.avatarColor != null) continue;

      needsSave = true;
      if (c is ManualCharacter) {
        _characters[i] = c.copyWith(
          avatarColor: Character.generateAvatarColor(),
        );
      } else if (c is BangumiCharacter) {
        _characters[i] = c.copyWith(
          avatarColor: Character.generateAvatarColor(),
        );
      }
    }
    if (needsSave) {
      await _storageService.saveAll(_characters);
      debugPrint('avatarColor 迁移完成');
    }
  }

  /// 导入角色数据（用于数据同步）
  ///
  /// [mode] 'merge' 合并（保留已有，补充新的），'replace' 完全替换
  /// 返回 (added, updated, total)
  Future<({int added, int updated, int total})> importCharacters(
    List<Character> imported, {
    String mode = 'merge',
    List<int> bangumiIdsOnly = const [],
  }) async {
    if (mode == 'replace') {
      // ── replace 模式 ──
      final localSelf = selfCharacter;
      final importedHasSelf = imported.any(
        (c) => c is ManualCharacter && c.isSelf,
      );

      final existingByBangumiId = <int, BangumiCharacter>{};
      for (final c in _characters.whereType<BangumiCharacter>()) {
        existingByBangumiId[c.bangumiId] = c;
      }

      final toSave = <Character>[];
      for (final c in imported) {
        if (c is BangumiCharacter) {
          final prev = existingByBangumiId[c.bangumiId];
          if (prev != null) {
            toSave.add(
              c.copyWith(avatarColor: prev.avatarColor ?? c.avatarColor),
            );
          } else {
            toSave.add(c);
          }
        } else {
          toSave.add(c);
        }
      }

      if (!importedHasSelf && localSelf != null) {
        toSave.add(localSelf);
      }

      // bangumiId-only：收集需要异步拉取的
      final existingBids = toSave
          .whereType<BangumiCharacter>()
          .map((c) => c.bangumiId)
          .toSet();
      final bangumiDtosToFetch = <BangumiCharacterDto>[];
      for (final bid in bangumiIdsOnly) {
        if (!existingBids.contains(bid)) {
          bangumiDtosToFetch.add(
            BangumiCharacterDto(
              id: bid,
              name: 'Bangumi#$bid',
              originalData: const {},
            ),
          );
        }
      }

      _characters = toSave;
      notifyListeners();
      await _storageService.saveAll(toSave);
      await _migrateAvatarColors();

      if (bangumiDtosToFetch.isNotEmpty) {
        addBangumiCharactersAsync(bangumiDtosToFetch);
      }

      return (added: toSave.length, updated: 0, total: toSave.length);
    }

    // ── merge 模式 ──
    final existing = List<Character>.from(_characters);
    final existingBangumiIds = existing
        .whereType<BangumiCharacter>()
        .map((c) => c.bangumiId)
        .toSet();

    final existingKeys = <String>{};
    for (final c in existing) {
      existingKeys.add('${c.name}_${c.birthMonth}_${c.birthDay}');
    }

    int added = 0;
    int updated = 0;

    for (final c in imported) {
      if (c is ManualCharacter && c.isSelf) continue;

      if (c is BangumiCharacter && existingBangumiIds.contains(c.bangumiId)) {
        continue;
      }

      final key = '${c.name}_${c.birthMonth}_${c.birthDay}';
      if (existingKeys.contains(key)) {
        continue;
      }

      final existingIdx = existing.indexWhere((e) => e.id == c.id);
      if (existingIdx >= 0) {
        existing[existingIdx] = c;
        updated++;
      } else {
        existing.add(c);
        added++;
      }
      existingKeys.add(key);
    }

    // bangumiId-only
    final bangumiDtosToFetch = <BangumiCharacterDto>[];
    for (final bid in bangumiIdsOnly) {
      if (!existingBangumiIds.contains(bid)) {
        bangumiDtosToFetch.add(
          BangumiCharacterDto(
            id: bid,
            name: 'Bangumi#$bid',
            originalData: const {},
          ),
        );
      }
    }

    _characters = existing;
    notifyListeners();
    await _storageService.saveAll(existing);
    await _migrateAvatarColors();

    if (bangumiDtosToFetch.isNotEmpty) {
      addBangumiCharactersAsync(bangumiDtosToFetch);
    }

    return (added: added, updated: updated, total: existing.length);
  }

  Future<void> _repairSelfFlag() async {
    final selfList = _characters
        .whereType<ManualCharacter>()
        .where((c) => c.isSelf)
        .toList();
    if (selfList.length <= 1) return;

    for (final manual in selfList.skip(1)) {
      final index = _characters.indexWhere((c) => c.id == manual.id);
      if (index != -1) {
        _characters[index] = manual.copyWith(isSelf: false);
      }
    }
    await _storageService.saveAll(_characters);
  }
}
