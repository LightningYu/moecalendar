import 'dart:collection';

import 'package:flutter/material.dart';

import '../models/character_model.dart';
import '../services/storage_service.dart';
import '../services/image_download_service.dart';
import '../bangumi/bangumi.dart';

class CharacterProvider extends ChangeNotifier {
  CharacterProvider() {
    _init();
  }

  final StorageService _storageService = StorageService();
  final ImageDownloadService _imageService = ImageDownloadService();

  List<Character> _characters = [];

  /// 获取图片下载服务（供 UI 监听进度）
  ImageDownloadService get imageDownloadService => _imageService;

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
    _imageService.onImageReady = _onImageReady;
    _imageService.addListener(_onDownloadProgress);
    // 恢复之前未完成的下载任务
    await _imageService.init();
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
  /// 直接从搜索 DTO 创建角色入库（DTO 中已有完整 JSON 数据），
  /// 缺少生日的角色直接跳过不入库。
  /// 入库后由 [_syncDownloads] 驱动图片下载。
  void addBangumiCharactersAsync(List<BangumiCharacterDto> dtoList) {
    _processBangumiCharactersBatch(dtoList);
  }

  /// 批量处理 Bangumi 角色：只入库有生日的，图片下载由库数据驱动
  Future<void> _processBangumiCharactersBatch(
    List<BangumiCharacterDto> dtoList,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    int addedCount = 0;
    int skippedCount = 0;

    for (int i = 0; i < dtoList.length; i++) {
      final dto = dtoList[i];

      // 缺少生日的直接跳过
      if (!dto.hasBirthday) {
        skippedCount++;
        continue;
      }

      final String id = '${now}_$i';
      final int notificationId = (now + i) & 0x7FFFFFFF;

      final newCharacter = BangumiCharacter(
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

      await _storageService.saveCharacter(newCharacter);
      addedCount++;
    }

    if (addedCount > 0) {
      await _loadData();
      // 入库后扫描并提交图片下载
      _syncDownloads();
    }

    debugPrint('批量添加完成: 添加 $addedCount 个，跳过 $skippedCount 个（无生日）');
  }

  /// 扫描库中所有 Bangumi 角色，将缺少本地图片的提交到下载队列
  ///
  /// 下载服务是响应库数据的——库里有什么角色，就下载什么图片。
  void _syncDownloads() {
    for (final c in _characters) {
      if (c is! BangumiCharacter) continue;
      // 已有完成的任务就跳过
      final existing = _imageService.getTask(c.id);
      if (existing != null &&
          existing.status == DownloadStatus.completed &&
          !existing.hasUnfinishedWork) {
        continue;
      }
      // 已有进行中的任务也跳过
      if (existing != null &&
          (existing.status == DownloadStatus.pending ||
              existing.status == DownloadStatus.downloading)) {
        continue;
      }
      // 有网络 URL 但缺少本地缓存 → 加入队列
      final needsGrid =
          c.gridAvatarPath != null &&
          c.gridAvatarPath!.startsWith('http') &&
          _imageService.getCachedGridPath(c.id) == null;
      final needsLarge =
          c.largeAvatarPath != null &&
          c.largeAvatarPath!.startsWith('http') &&
          _imageService.getCachedLargePath(c.id) == null;

      if (needsGrid || needsLarge) {
        _imageService.enqueue(
          characterId: c.id,
          characterName: c.name,
          gridUrl: needsGrid ? c.gridAvatarPath : null,
          largeUrl: needsLarge ? c.largeAvatarPath : null,
        );
      }
    }
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

  /// 下载进度更新 → 通知 UI 刷新
  void _onDownloadProgress() {
    notifyListeners();
  }

  @override
  void dispose() {
    _imageService.removeListener(_onDownloadProgress);
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
  Future<({int added, int updated, int total})> importCharacters(
    List<Character> imported, {
    String mode = 'merge',
  }) async {
    if (mode == 'replace') {
      await _storageService.saveAll(imported);
      await _loadData();
      await _migrateAvatarColors();
      _syncDownloads();
      return (added: imported.length, updated: 0, total: imported.length);
    }

    // merge 模式
    final existing = await _storageService.getCharacters();
    final existingIds = existing.map((c) => c.id).toSet();
    // 对于 BangumiCharacter，也按 bangumiId 去重
    final existingBangumiIds = existing
        .whereType<BangumiCharacter>()
        .map((c) => c.bangumiId)
        .toSet();

    int added = 0;
    int updated = 0;

    for (final c in imported) {
      if (c is BangumiCharacter && existingBangumiIds.contains(c.bangumiId)) {
        // bangumiId 已存在 → 跳过
        continue;
      }
      if (existingIds.contains(c.id)) {
        // id 完全匹配 → 更新
        final idx = existing.indexWhere((e) => e.id == c.id);
        existing[idx] = c;
        updated++;
      } else {
        existing.add(c);
        added++;
      }
    }

    await _storageService.saveAll(existing);
    await _loadData();
    await _migrateAvatarColors();
    _syncDownloads();
    return (added: added, updated: updated, total: existing.length);
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
