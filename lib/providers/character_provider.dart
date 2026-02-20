import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/character_model.dart';
import '../services/storage_service.dart';
import '../services/task_pool_service.dart';
import '../bangumi/bangumi.dart';

class CharacterProvider extends ChangeNotifier {
  CharacterProvider() {
    _init();
  }

  final StorageService _storageService = StorageService();
  final TaskPoolService _taskPool = TaskPoolService();

  List<Character> _characters = [];

  /// 获取任务池服务（供 UI 监听进度）
  TaskPoolService get taskPoolService => _taskPool;

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

  Future<void> _init() async {
    await _loadData();
    await _migrateAvatarColors();
    // 设置任务池回调
    _taskPool.onCharacterReady = _onCharacterReady;
    _taskPool.onImageReady = _onImageReady;
    _taskPool.addListener(_onTaskPoolProgress);
    // 恢复之前未完成的任务
    await _taskPool.init();
    // 扫描库中缺少本地图片的 Bangumi 角色，提交下载
    _syncDownloads();
  }

  /// 新增角色
  Future<void> addCharacter(Character character) async {
    await _storageService.saveCharacter(character);
    await _loadData();
  }

  /// 更新角色
  Future<void> updateCharacter(Character character) async {
    await _storageService.saveCharacter(character);
    await _loadData();
  }

  /// 删除角色
  Future<void> deleteCharacter(String id) async {
    await _storageService.deleteCharacter(id);
    await _loadData();
  }

  /// 新增或更新自己的生日信息
  Future<ManualCharacter> upsertSelfCharacter({
    required DateTime birthday,
    required bool isLunar,
    String? displayName,
  }) async {
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

    await _storageService.saveCharacter(updated);
    await _loadData();
    return updated;
  }

  /// 刷新数据
  Future<void> refresh() async {
    await _loadData();
  }

  /// 批量添加 Bangumi 角色（非阻塞）
  ///
  /// 直接将 bangumiId 提交到统一任务池，由任务池负责：
  /// 拉取详情 → 判断生日 → 入库 → 下载图片
  void addBangumiCharactersAsync(List<BangumiCharacterDto> dtoList) {
    final items = dtoList
        .map((dto) => (bangumiId: dto.id, name: dto.displayName))
        .toList();
    _taskPool.submitAll(items);
  }

  /// 扫描库中所有 Bangumi 角色，将缺少本地图片的提交到任务池
  void _syncDownloads() {
    for (final c in _characters) {
      if (c is! BangumiCharacter) continue;

      final existing = _taskPool.getTask(c.bangumiId);

      // 正在处理中 → 跳过
      if (existing != null &&
          (existing.status == TaskStatus.pending ||
              existing.status == TaskStatus.running)) {
        continue;
      }

      // 判断 DB 里路径是否已落地本地（且文件真实存在）
      final dbGridIsLocal =
          c.gridAvatarPath != null &&
          !c.gridAvatarPath!.startsWith('http') &&
          File(c.gridAvatarPath!).existsSync();
      final dbLargeIsLocal =
          c.largeAvatarPath != null &&
          !c.largeAvatarPath!.startsWith('http') &&
          File(c.largeAvatarPath!).existsSync();

      // 如果 DB 里两张图都已是本地且文件存在 → 无需操作
      if (dbGridIsLocal && dbLargeIsLocal) continue;

      // 判断任务池是否已有本地路径（已下载但未写回 DB，由 _syncTaskPoolPathsToDB 处理）
      final taskGridOk =
          existing?.gridLocalPath != null &&
          File(existing!.gridLocalPath!).existsSync();
      final taskLargeOk =
          existing?.largeLocalPath != null &&
          File(existing!.largeLocalPath!).existsSync();

      // 预期本地路径已存在（可能是之前用同一 bangumiId 下载过）
      final predictedGridPath = TaskPoolService.expectedGridPath(
        c.bangumiId,
        c.gridAvatarPath,
      );
      final predictedLargeExpected = TaskPoolService.expectedLargePath(
        c.bangumiId,
        c.largeAvatarPath,
      );
      final predictedGridOk =
          predictedGridPath != null && File(predictedGridPath).existsSync();
      final predictedLargeOk =
          predictedLargeExpected != null &&
          File(predictedLargeExpected).existsSync();

      // 需要从网络下载的 URL
      final gridOk = dbGridIsLocal || taskGridOk || predictedGridOk;
      final largeOk = dbLargeIsLocal || taskLargeOk || predictedLargeOk;

      final needsGrid =
          !gridOk &&
          c.gridAvatarPath != null &&
          c.gridAvatarPath!.startsWith('http');
      final needsLarge =
          !largeOk &&
          c.largeAvatarPath != null &&
          c.largeAvatarPath!.startsWith('http');

      if (needsGrid || needsLarge) {
        _taskPool.submitImageDownload(
          bangumiId: c.bangumiId,
          characterId: c.id,
          characterName: c.name,
          gridUrl: needsGrid ? c.gridAvatarPath : null,
          largeUrl: needsLarge ? c.largeAvatarPath : null,
        );
      }
    }
  }

  /// 公开刷新：同步任务池路径到 DB，然后扫描缺图毛角色并补下载
  ///
  /// 适用于：手动刷新、导入后故障诊断等场景
  Future<void> refreshImageCache() async {
    await _syncTaskPoolPathsToDB();
    _syncDownloads();
  }

  /// 添加单个在线 Bangumi 角色（先入库，图片由同步驱动）
  Future<BangumiCharacter?> addBangumiCharacterFromDto(
    BangumiCharacterDto dto,
  ) async {
    if (!dto.hasBirthday) return null;

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final notificationId = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;

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

    await _storageService.saveCharacter(newChar);
    await _loadData();
    _syncDownloads();

    return newChar;
  }

  /// 刷新本地 Bangumi 角色数据（重新拉取 API + 同步下载图片）
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

    await _storageService.saveCharacter(updated);
    await _loadData();
    _syncDownloads();

    return updated;
  }

  /// 任务池回调：角色入库
  /// 返回入库后的 characterId
  Future<String?> _onCharacterReady(BangumiCharacterDto dto) async {
    if (!dto.hasBirthday) return null;

    // 检查是否已有相同 bangumiId 的角色
    final existing = _characters.whereType<BangumiCharacter>().where(
      (c) => c.bangumiId == dto.id,
    );
    if (existing.isNotEmpty) {
      return existing.first.id;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = now.toString();
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

    await _storageService.saveCharacter(newChar);
    await _loadData();
    return id;
  }

  /// 图片下载回调 → 更新角色的本地路径（每下载完一张就调用一次）
  Future<void> _onImageReady(
    String characterId,
    String? gridPath,
    String? largePath,
  ) async {
    final index = _characters.indexWhere((c) => c.id == characterId);
    if (index < 0) return;

    final c = _characters[index];
    if (c is! BangumiCharacter) return;

    final updated = c.copyWith(
      gridAvatarPath: gridPath ?? c.gridAvatarPath,
      largeAvatarPath: largePath ?? c.largeAvatarPath,
      avatarPath: largePath ?? c.avatarPath,
    );

    await _storageService.saveCharacter(updated);
    _characters[index] = updated;
    notifyListeners();
  }

  /// 任务池进度更新 → 通知 UI 刷新
  void _onTaskPoolProgress() {
    notifyListeners();
  }

  @override
  void dispose() {
    _taskPool.removeListener(_onTaskPoolProgress);
    super.dispose();
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
  /// 对于只含 bangumiId 的 Bangumi 角色，会提交到任务池拉取详情
  Future<({int added, int updated, int total, int taskSubmitted})>
  importCharacters(
    List<Character> imported, {
    String mode = 'merge',
    List<int> bangumiIdsOnly = const [],
  }) async {
    if (mode == 'replace') {
      // ── replace 模式 ──
      // 1. 检查导入数据是否含 self；如果没有，保留本地的 self
      final localSelf = selfCharacter;
      final importedHasSelf = imported.any(
        (c) => c is ManualCharacter && c.isSelf,
      );

      // 2. 建立当前库的 bangumiId → 角色映射，用于复用本地路径
      final existingByBangumiId = <int, BangumiCharacter>{};
      for (final c in _characters.whereType<BangumiCharacter>()) {
        existingByBangumiId[c.bangumiId] = c;
      }

      // 3. 构建最终写入列表：相同 bangumiId 保留本地已下载的图片路径
      final toSave = <Character>[];
      for (final c in imported) {
        if (c is BangumiCharacter) {
          final prev = existingByBangumiId[c.bangumiId];
          if (prev != null) {
            toSave.add(
              c.copyWith(
                gridAvatarPath: _pickBestPath(
                  prev.gridAvatarPath,
                  c.gridAvatarPath,
                ),
                largeAvatarPath: _pickBestPath(
                  prev.largeAvatarPath,
                  c.largeAvatarPath,
                ),
                avatarPath: _pickBestPath(prev.avatarPath, c.avatarPath),
                avatarColor: prev.avatarColor ?? c.avatarColor,
              ),
            );
          } else {
            toSave.add(c);
          }
        } else {
          toSave.add(c);
        }
      }

      // 4. 导入数据没有 self → 补回本地 self
      if (!importedHasSelf && localSelf != null) {
        toSave.add(localSelf);
      }

      await _storageService.saveAll(toSave);
      await _loadData();
      await _migrateAvatarColors();

      // 5. 把任务池已有的本地路径同步回 DB
      await _syncTaskPoolPathsToDB();

      // 6. 扫描仍缺图的角色，提交补下载
      _syncDownloads();

      // 7. bangumiId-only：已在库的由 _syncDownloads 处理，其余提交任务池
      final existingBids = _characters
          .whereType<BangumiCharacter>()
          .map((c) => c.bangumiId)
          .toSet();
      int taskSubmitted = 0;
      for (final bid in bangumiIdsOnly) {
        if (!existingBids.contains(bid)) {
          _taskPool.submit(bid);
          taskSubmitted++;
        }
      }
      return (
        added: toSave.length,
        updated: 0,
        total: toSave.length,
        taskSubmitted: taskSubmitted,
      );
    }

    // ── merge 模式 ──
    final existing = await _storageService.getCharacters();
    final existingBangumiIds = existing
        .whereType<BangumiCharacter>()
        .map((c) => c.bangumiId)
        .toSet();

    // 构建"名字+月+日"的去重集合
    final existingKeys = <String>{};
    for (final c in existing) {
      existingKeys.add('${c.name}_${c.birthMonth}_${c.birthDay}');
    }

    int added = 0;
    int updated = 0;

    for (final c in imported) {
      // merge 模式：跳过 isSelf，保留本地的 self 不变
      if (c is ManualCharacter && c.isSelf) continue;

      if (c is BangumiCharacter && existingBangumiIds.contains(c.bangumiId)) {
        continue; // bangumiId 已存在 → 跳过
      }

      final key = '${c.name}_${c.birthMonth}_${c.birthDay}';
      if (existingKeys.contains(key)) {
        continue; // 同名同日期 → 跳过
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

    // 将 bangumiId-only 中不重复的提交到任务池
    int taskSubmitted = 0;
    for (final bid in bangumiIdsOnly) {
      if (!existingBangumiIds.contains(bid)) {
        _taskPool.submit(bid);
        taskSubmitted++;
      }
    }

    await _storageService.saveAll(existing);
    await _loadData();
    await _migrateAvatarColors();

    // 把任务池已有的本地路径同步回 DB
    await _syncTaskPoolPathsToDB();

    _syncDownloads();
    return (
      added: added,
      updated: updated,
      total: existing.length,
      taskSubmitted: taskSubmitted,
    );
  }

  /// 将任务池中已下载的本地图片路径写回对应角色的 DB 记录
  ///
  /// 场景：导入时 DB 里路径是 HTTP URL（来自备份），
  /// 而任务池已有完成的本地路径，将两者同步，避免重复下载。
  Future<void> _syncTaskPoolPathsToDB() async {
    bool changed = false;
    for (int i = 0; i < _characters.length; i++) {
      final c = _characters[i];
      if (c is! BangumiCharacter) continue;

      final task = _taskPool.getTask(c.bangumiId);
      if (task == null) continue;

      final gridNeedsUpdate =
          task.gridLocalPath != null &&
          (c.gridAvatarPath == null || c.gridAvatarPath!.startsWith('http'));
      final largeNeedsUpdate =
          task.largeLocalPath != null &&
          (c.largeAvatarPath == null || c.largeAvatarPath!.startsWith('http'));

      if (!gridNeedsUpdate && !largeNeedsUpdate) continue;

      final updated = c.copyWith(
        gridAvatarPath: gridNeedsUpdate ? task.gridLocalPath : c.gridAvatarPath,
        largeAvatarPath: largeNeedsUpdate
            ? task.largeLocalPath
            : c.largeAvatarPath,
        avatarPath: largeNeedsUpdate ? task.largeLocalPath : c.avatarPath,
      );
      _characters[i] = updated;
      await _storageService.saveCharacter(updated);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// 优先选取本地路径（不以 http 开头的视为本地路径）
  String? _pickBestPath(String? localCandidate, String? fallback) {
    if (localCandidate != null && !localCandidate.startsWith('http')) {
      return localCandidate;
    }
    return fallback;
  }

  Future<void> _repairSelfFlag() async {
    final selfList = _characters
        .whereType<ManualCharacter>()
        .where((c) => c.isSelf)
        .toList();
    if (selfList.length <= 1) return;

    // 保留第一个自我角色，其余降级为普通角色
    for (final manual in selfList.skip(1)) {
      final index = _characters.indexWhere((c) => c.id == manual.id);
      if (index != -1) {
        _characters[index] = manual.copyWith(isSelf: false);
      }
    }
    await _storageService.saveAll(_characters);
  }
}
