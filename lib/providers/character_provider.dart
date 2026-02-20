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
    _imageService.onImageReady = _onImageReady;
    _imageService.addListener(_onDownloadProgress);
    // 恢复之前未完成的下载任务
    await _imageService.init();
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
  /// 立即用搜索结果中已有的信息创建占位角色（含名称和图片 URL），
  /// 然后在后台并发拉取详情以补全生日等信息。
  void addBangumiCharactersAsync(List<BangumiCharacterDto> dtoList) {
    _processBangumiCharactersBatch(dtoList);
  }

  /// 后台批量处理 Bangumi 角色
  ///
  /// 分两阶段：
  /// 1. 立即阶段：用搜索 DTO 中已有数据创建占位角色并入库、提交图片下载
  /// 2. 补全阶段：并发拉取详情 API，补全生日 / originalData 等信息
  Future<void> _processBangumiCharactersBatch(
    List<BangumiCharacterDto> dtoList,
  ) async {
    final bangumiService = BangumiService();
    final now = DateTime.now().millisecondsSinceEpoch;

    // ───── 阶段 1：立即创建占位角色 ─────
    final List<_PendingBangumiEntry> pendingEntries = [];

    for (int i = 0; i < dtoList.length; i++) {
      final dto = dtoList[i];
      final String id = '${now}_$i';
      final int notificationId = (now + i) & 0x7FFFFFFF;

      // 搜索列表已经有生日的直接使用；没有的先占位 1/1，后续由详情补全
      final bool hasBirthday = dto.hasBirthday;

      final placeholder = BangumiCharacter(
        id: id,
        notificationId: notificationId,
        name: dto.displayName,
        birthYear: dto.birthYear,
        birthMonth: dto.birthMon ?? 1,
        birthDay: dto.birthDay ?? 1,
        notify: hasBirthday, // 没有生日信息的先关闭通知
        avatarPath: dto.avatarLargeUrl,
        bangumiId: dto.id,
        originalData: dto.originalData,
        gridAvatarPath: dto.avatarGridUrl,
        largeAvatarPath: dto.avatarLargeUrl,
        avatarColor: Character.generateAvatarColor(),
      );

      await _storageService.saveCharacter(placeholder);

      // 提交图片下载
      _imageService.enqueue(
        characterId: id,
        characterName: placeholder.name,
        gridUrl: dto.avatarGridUrl,
        largeUrl: dto.avatarLargeUrl,
      );

      // 搜索结果缺少生日 → 需要拉详情补全
      if (!hasBirthday) {
        pendingEntries.add(_PendingBangumiEntry(charId: id, bangumiId: dto.id));
      }
    }

    // 立即刷新 UI，让占位角色显示出来
    await _loadData();
    debugPrint('批量占位创建完成: ${dtoList.length} 个');

    // ───── 阶段 2：并发拉取详情补全缺失的生日信息 ─────
    if (pendingEntries.isEmpty) return;

    final futures = pendingEntries.map((entry) async {
      try {
        final detail = await bangumiService.getCharacterDetail(entry.bangumiId);
        if (detail == null) return;

        final index = _characters.indexWhere((c) => c.id == entry.charId);
        if (index < 0) return;
        final existing = _characters[index];
        if (existing is! BangumiCharacter) return;

        if (detail.birthMon != null && detail.birthDay != null) {
          // 补全生日和完整 originalData
          final updated = existing.copyWith(
            name: detail.displayName,
            birthYear: detail.birthYear,
            birthMonth: detail.birthMon,
            birthDay: detail.birthDay,
            notify: true,
            originalData: detail.originalData,
            gridAvatarPath: detail.avatarGridUrl ?? existing.gridAvatarPath,
            largeAvatarPath: detail.avatarLargeUrl ?? existing.largeAvatarPath,
            avatarPath: detail.avatarLargeUrl ?? existing.avatarPath,
          );
          await _storageService.saveCharacter(updated);
          _characters[index] = updated;
        } else {
          // 详情也没有生日 → 仅补全 originalData，保持 notify=false
          final updated = existing.copyWith(
            name: detail.displayName,
            originalData: detail.originalData,
          );
          await _storageService.saveCharacter(updated);
          _characters[index] = updated;
        }
      } catch (e) {
        debugPrint('补全角色详情失败 [${entry.bangumiId}]: $e');
      }
    });

    await Future.wait(futures);
    notifyListeners();
    debugPrint('批量详情补全完成: ${pendingEntries.length} 个');
  }

  /// 添加单个在线 Bangumi 角色（先入库，后台下载图片）
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

    // 后台下载图片
    _imageService.enqueue(
      characterId: id,
      characterName: newChar.name,
      gridUrl: dto.avatarGridUrl,
      largeUrl: dto.avatarLargeUrl,
    );

    return newChar;
  }

  /// 刷新本地 Bangumi 角色数据（重新拉取 API + 后台下载图片）
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

    // 后台下载新图片
    _imageService.enqueue(
      characterId: bangumiChar.id,
      characterName: updated.name,
      gridUrl: dto.avatarGridUrl,
      largeUrl: dto.avatarLargeUrl,
    );

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

/// 批量添加时记录"需要后台补全详情"的占位条目
class _PendingBangumiEntry {
  final String charId;
  final int bangumiId;
  const _PendingBangumiEntry({required this.charId, required this.bangumiId});
}
