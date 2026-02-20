import 'dart:collection';

import 'package:flutter/material.dart';

import '../models/character_model.dart';
import '../services/storage_service.dart';
import '../services/image_download_service.dart';
import '../bangumi/bangumi.dart';

class CharacterProvider extends ChangeNotifier {
  CharacterProvider() {
    _loadData();
    _imageService.onDownloadComplete = _onImageDownloaded;
    _imageService.addListener(_onDownloadProgress);
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

  /// 批量添加 Bangumi 角色（先入库，后台下载图片）
  ///
  /// 返回 (addedCount, skippedCount)
  Future<(int, int)> addBangumiCharacters(
    List<BangumiCharacterDto> dtoList,
  ) async {
    final bangumiService = BangumiService();
    int addedCount = 0;
    int skippedCount = 0;

    for (final simpleDto in dtoList) {
      final detailDto = await bangumiService.getCharacterDetail(simpleDto.id);

      if (detailDto == null ||
          detailDto.birthMon == null ||
          detailDto.birthDay == null) {
        skippedCount++;
        continue;
      }

      final String id =
          DateTime.now().millisecondsSinceEpoch.toString() +
          addedCount.toString();
      final int notificationId =
          (DateTime.now().millisecondsSinceEpoch + addedCount) & 0x7FFFFFFF;

      // 先入库，头像路径暂存网络 URL
      final newCharacter = BangumiCharacter(
        id: id,
        notificationId: notificationId,
        name: detailDto.nameCn ?? detailDto.name,
        birthYear: detailDto.birthYear,
        birthMonth: detailDto.birthMon!,
        birthDay: detailDto.birthDay!,
        notify: true,
        avatarPath: detailDto.avatarLargeUrl,
        bangumiId: detailDto.id,
        originalData: detailDto.originalData,
        gridAvatarPath: detailDto.avatarGridUrl,
        largeAvatarPath: detailDto.avatarLargeUrl,
      );

      await _storageService.saveCharacter(newCharacter);
      addedCount++;

      // 将图片下载任务加入后台队列
      _imageService.enqueue(
        characterId: id,
        characterName: newCharacter.name,
        gridUrl: detailDto.avatarGridUrl,
        largeUrl: detailDto.avatarLargeUrl,
      );
    }

    await _loadData();
    return (addedCount, skippedCount);
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

  /// 图片下载完成回调 → 更新角色的本地路径
  Future<void> _onImageDownloaded(
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
