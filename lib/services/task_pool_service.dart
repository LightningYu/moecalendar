import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../bangumi/bangumi.dart';
import '../utils/path_manager.dart';

/// 统一任务阶段
enum TaskPhase {
  /// 拉取角色详情（最高优先级）
  fetchDetail,

  /// 下载 grid 头像
  downloadGrid,

  /// 下载 large 头像
  downloadLarge,

  /// 所有阶段完成
  done,
}

/// 任务状态
enum TaskStatus {
  /// 排队等待
  pending,

  /// 正在执行
  running,

  /// 全部完成
  completed,

  /// 失败
  failed,

  /// 跳过（无生日等原因）
  skipped,
}

/// 统一任务：拉详情 → 入库 → 下载图片
class PoolTask {
  /// 使用 bangumiId 作为任务唯一标识
  final int bangumiId;

  /// 角色名称（用于显示，可能在拉取详情后更新）
  String characterName;

  /// 当前阶段
  TaskPhase phase;

  /// 当前状态
  TaskStatus status;

  /// 下载进度 0.0~1.0（仅图片下载阶段有意义）
  double progress;

  /// 错误信息
  String? error;

  /// 入库后的 character id（null 表示还未入库）
  String? characterId;

  /// 详情数据（拉取成功后暂存，入库后清空以节省内存）
  BangumiCharacterDto? detailDto;

  /// Grid 图片 URL
  String? gridUrl;

  /// Large 图片 URL
  String? largeUrl;

  /// 本地 grid 头像路径
  String? gridLocalPath;

  /// 本地 large 头像路径
  String? largeLocalPath;

  /// 是否有生日
  bool? hasBirthday;

  PoolTask({
    required this.bangumiId,
    this.characterName = '',
    this.phase = TaskPhase.fetchDetail,
    this.status = TaskStatus.pending,
    this.progress = 0.0,
    this.error,
    this.characterId,
    this.gridUrl,
    this.largeUrl,
    this.gridLocalPath,
    this.largeLocalPath,
    this.hasBirthday,
  });

  /// 序列化
  Map<String, dynamic> toJson() => {
    'bangumiId': bangumiId,
    'characterName': characterName,
    'phase': phase.index,
    'status': status.index,
    'characterId': characterId,
    'gridUrl': gridUrl,
    'largeUrl': largeUrl,
    'gridLocalPath': gridLocalPath,
    'largeLocalPath': largeLocalPath,
    'hasBirthday': hasBirthday,
  };

  /// 反序列化
  ///
  /// 加载时校验本地图片文件是否真实存在，若文件已丢失则清除对应路径，
  /// 避免任务池误认为已下载完成而跳过重新下载。
  factory PoolTask.fromJson(Map<String, dynamic> json) {
    final phaseIdx = json['phase'] as int? ?? 0;
    final statusIdx = json['status'] as int? ?? 0;

    String? gridLocalPath = json['gridLocalPath'] as String?;
    String? largeLocalPath = json['largeLocalPath'] as String?;

    // 校验文件实际存在，若文件已丢失则清除路径
    if (gridLocalPath != null && !File(gridLocalPath).existsSync()) {
      gridLocalPath = null;
    }
    if (largeLocalPath != null && !File(largeLocalPath).existsSync()) {
      largeLocalPath = null;
    }

    // 若文件丢失导致路径被清除，状态也应当重置为 pending 重新下载
    int effectiveStatus = statusIdx.clamp(0, TaskStatus.values.length - 1);
    int effectivePhase = phaseIdx.clamp(0, TaskPhase.values.length - 1);

    final originalStatus = TaskStatus.values[effectiveStatus];
    final originalPhase = TaskPhase.values[effectivePhase];

    if (originalStatus == TaskStatus.completed) {
      final gridUrl = json['gridUrl'] as String?;
      final largeUrl = json['largeUrl'] as String?;
      final gridMissing = gridUrl != null && gridLocalPath == null;
      final largeMissing = largeUrl != null && largeLocalPath == null;

      if (gridMissing || largeMissing) {
        // 文件丢失，降级回 pending 补下载
        effectiveStatus = TaskStatus.pending.index;
        effectivePhase = gridMissing
            ? TaskPhase.downloadGrid.index
            : TaskPhase.downloadLarge.index;
      }
    }

    return PoolTask(
      bangumiId: json['bangumiId'] as int,
      characterName: json['characterName'] as String? ?? '',
      phase: TaskPhase.values[effectivePhase],
      status: TaskStatus.values[effectiveStatus],
      characterId: json['characterId'] as String?,
      gridUrl: json['gridUrl'] as String?,
      largeUrl: json['largeUrl'] as String?,
      gridLocalPath: gridLocalPath,
      largeLocalPath: largeLocalPath,
      hasBirthday: json['hasBirthday'] as bool?,
    );
  }

  /// 人类可读的状态描述
  String get statusText {
    switch (status) {
      case TaskStatus.pending:
        return _phaseText;
      case TaskStatus.running:
        return _phaseText;
      case TaskStatus.completed:
        return '完成';
      case TaskStatus.failed:
        return '失败: ${error ?? "未知错误"}';
      case TaskStatus.skipped:
        return '跳过: 无生日信息';
    }
  }

  String get _phaseText {
    switch (phase) {
      case TaskPhase.fetchDetail:
        return '等待获取详情';
      case TaskPhase.downloadGrid:
        return '下载小图';
      case TaskPhase.downloadLarge:
        return '下载大图';
      case TaskPhase.done:
        return '完成';
    }
  }

  /// 是否需要下载图片
  bool get needsImageDownload =>
      phase == TaskPhase.downloadGrid || phase == TaskPhase.downloadLarge;

  /// 是否是最终状态（完成/跳过/失败 且 非 pending）
  bool get isTerminal =>
      status == TaskStatus.completed ||
      status == TaskStatus.skipped ||
      (status == TaskStatus.failed && phase == TaskPhase.fetchDetail);
}

/// 统一任务池服务
///
/// 生命周期：bangumiId 提交 → 拉取详情 → 判断生日 → 入库 → 下载 grid → 下载 large
/// 优先级：详情拉取 > grid 下载 > large 下载
/// 最大并发 [_maxConcurrent] 个网络请求
class TaskPoolService extends ChangeNotifier {
  static final TaskPoolService _instance = TaskPoolService._internal();
  factory TaskPoolService() => _instance;
  TaskPoolService._internal();

  final Dio _dio = Dio();
  final BangumiService _bangumiService = BangumiService();

  /// 所有任务（按 bangumiId 索引）
  final Map<int, PoolTask> _tasks = {};

  /// 角色入库回调：(BangumiCharacterDto dto) → characterId
  /// 由 CharacterProvider 设置
  Future<String?> Function(BangumiCharacterDto dto)? onCharacterReady;

  /// 图片下载完成回调：(characterId, gridPath?, largePath?)
  /// 由 CharacterProvider 设置
  void Function(String characterId, String? gridPath, String? largePath)?
  onImageReady;

  static const int _maxConcurrent = 3;
  int _activeWorkers = 0;
  bool _initialized = false;

  String get _tasksFilePath =>
      path.join(PathManager().documentsPath, 'task_pool.json');

  // ============ 公开 API ============

  /// 获取所有任务（不可变视图）
  List<PoolTask> get allTasks => List.unmodifiable(_tasks.values.toList());

  /// 获取某个任务
  PoolTask? getTask(int bangumiId) => _tasks[bangumiId];

  /// 通过 characterId 获取任务
  PoolTask? getTaskByCharacterId(String characterId) {
    try {
      return _tasks.values.firstWhere((t) => t.characterId == characterId);
    } catch (_) {
      return null;
    }
  }

  /// 获取角色的已下载 grid 本地路径
  String? getCachedGridPath(String characterId) {
    final task = getTaskByCharacterId(characterId);
    return task?.gridLocalPath;
  }

  /// 获取角色的已下载 large 本地路径
  String? getCachedLargePath(String characterId) {
    final task = getTaskByCharacterId(characterId);
    return task?.largeLocalPath;
  }

  /// 获取用于列表显示的最佳本地路径（grid 优先）
  String? getCachedListAvatar(String characterId) {
    final task = getTaskByCharacterId(characterId);
    if (task == null) return null;
    return task.gridLocalPath ?? task.largeLocalPath;
  }

  /// 获取用于详情显示的最佳本地路径（large 优先）
  String? getCachedDetailAvatar(String characterId) {
    final task = getTaskByCharacterId(characterId);
    if (task == null) return null;
    return task.largeLocalPath ?? task.gridLocalPath;
  }

  /// 是否有正在进行的任务
  bool get hasActiveTasks => _tasks.values.any(
    (t) => t.status == TaskStatus.pending || t.status == TaskStatus.running,
  );

  /// 活跃任务数量
  int get activeTaskCount => _tasks.values
      .where(
        (t) => t.status == TaskStatus.pending || t.status == TaskStatus.running,
      )
      .length;

  /// 统计信息
  ({int total, int completed, int failed, int skipped, int active}) get stats {
    int total = _tasks.length;
    int completed = 0;
    int failed = 0;
    int skipped = 0;
    int active = 0;
    for (final t in _tasks.values) {
      switch (t.status) {
        case TaskStatus.completed:
          completed++;
        case TaskStatus.failed:
          failed++;
        case TaskStatus.skipped:
          skipped++;
        case TaskStatus.pending:
        case TaskStatus.running:
          active++;
      }
    }
    return (
      total: total,
      completed: completed,
      failed: failed,
      skipped: skipped,
      active: active,
    );
  }

  /// 初始化：加载持久化任务、恢复状态
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadTasks();

    // 恢复中断的任务
    for (final task in _tasks.values) {
      if (task.status == TaskStatus.running) {
        task.status = TaskStatus.pending;
        task.progress = 0.0;
        task.error = null;
      }
      // failed 保持 failed，让用户手动重试
    }

    if (_tasks.values.any((t) => t.status == TaskStatus.pending)) {
      notifyListeners();
      _processQueue();
    }
  }

  /// 提交 bangumiId 到任务池
  ///
  /// 如果提供了 [name]，会作为初始显示名。
  /// 如果已有该 bangumiId 的完成/跳过任务，不会重复创建。
  void submit(int bangumiId, {String name = ''}) {
    final existing = _tasks[bangumiId];
    if (existing != null &&
        (existing.status == TaskStatus.completed ||
            existing.status == TaskStatus.skipped)) {
      return;
    }
    // 如果正在执行也跳过
    if (existing != null &&
        (existing.status == TaskStatus.pending ||
            existing.status == TaskStatus.running)) {
      return;
    }

    _tasks[bangumiId] = PoolTask(bangumiId: bangumiId, characterName: name);
    _saveTasks();
    notifyListeners();
    _processQueue();
  }

  /// 批量提交
  void submitAll(List<({int bangumiId, String name})> items) {
    bool added = false;
    for (final item in items) {
      final existing = _tasks[item.bangumiId];
      if (existing != null &&
          (existing.status == TaskStatus.completed ||
              existing.status == TaskStatus.skipped ||
              existing.status == TaskStatus.pending ||
              existing.status == TaskStatus.running)) {
        continue;
      }
      _tasks[item.bangumiId] = PoolTask(
        bangumiId: item.bangumiId,
        characterName: item.name,
      );
      added = true;
    }
    if (added) {
      _saveTasks();
      notifyListeners();
      _processQueue();
    }
  }

  /// 计算 grid 图片的预期本地路径（不依赖任务池状态，可跨会话使用）
  static String? expectedGridPath(int bangumiId, String? url) {
    if (url == null) return null;
    // 从 URL 取扩展名；若无扩展名则用 .jpg 兜底
    final ext = path.extension(url);
    final safExt = ext.isNotEmpty ? ext : '.jpg';
    return PathManager().getImagePath('grid_${bangumiId}$safExt');
  }

  /// 计算 large 图片的预期本地路径
  static String? expectedLargePath(int bangumiId, String? url) {
    if (url == null) return null;
    final ext = path.extension(url);
    final safExt = ext.isNotEmpty ? ext : '.jpg';
    return PathManager().getImagePath('large_${bangumiId}$safExt');
  }

  /// 为已在库中的 Bangumi 角色提交图片下载任务（跳过详情拉取阶段）
  void submitImageDownload({
    required int bangumiId,
    required String characterId,
    required String characterName,
    String? gridUrl,
    String? largeUrl,
  }) {
    if (gridUrl == null && largeUrl == null) return;

    // 先检查文件是否真实存在于磁盘，存在则直接返回（最可靠的去重逻辑）
    final gridExpected = expectedGridPath(bangumiId, gridUrl);
    final largeExpected = expectedLargePath(bangumiId, largeUrl);
    final gridFileExists =
        gridExpected != null && File(gridExpected).existsSync();
    final largeFileExists =
        largeExpected != null && File(largeExpected).existsSync();

    // 需要的文件都已存在 → 直接更新任务池状态为完成，无需下载
    if ((gridUrl == null || gridFileExists) &&
        (largeUrl == null || largeFileExists)) {
      // 确保任务池记录本地路径（方便 DB 同步）
      final existing = _tasks[bangumiId];
      if (existing != null) {
        if (gridFileExists && existing.gridLocalPath == null) {
          existing.gridLocalPath = gridExpected;
        }
        if (largeFileExists && existing.largeLocalPath == null) {
          existing.largeLocalPath = largeExpected;
        }
        _saveTasks();
      }
      return; // 文件已存在，无需下载
    }

    final existing = _tasks[bangumiId];
    if (existing != null &&
        existing.status == TaskStatus.completed &&
        existing.gridLocalPath != null &&
        (largeUrl == null || existing.largeLocalPath != null)) {
      return; // 任务池记录已完成无需重复
    }

    // 只需要下载尚缺的文件
    final needGrid = gridUrl != null && !gridFileExists;
    final needLarge = largeUrl != null && !largeFileExists;

    _tasks[bangumiId] = PoolTask(
      bangumiId: bangumiId,
      characterName: characterName,
      characterId: characterId,
      gridUrl: gridUrl,
      largeUrl: largeUrl,
      hasBirthday: true, // 已在库中说明有生日
      phase: needGrid
          ? TaskPhase.downloadGrid
          : (needLarge ? TaskPhase.downloadLarge : TaskPhase.done),
      status: (needGrid || needLarge)
          ? TaskStatus.pending
          : TaskStatus.completed,
    );
    _saveTasks();
    notifyListeners();
    _processQueue();
  }

  /// 重试失败的任务
  void retry(int bangumiId) {
    final task = _tasks[bangumiId];
    if (task == null || task.status != TaskStatus.failed) return;
    task.status = TaskStatus.pending;
    task.progress = 0.0;
    task.error = null;
    _saveTasks();
    notifyListeners();
    _processQueue();
  }

  /// 重试所有失败任务
  void retryAllFailed() {
    bool changed = false;
    for (final task in _tasks.values) {
      if (task.status == TaskStatus.failed) {
        task.status = TaskStatus.pending;
        task.progress = 0.0;
        task.error = null;
        changed = true;
      }
    }
    if (changed) {
      _saveTasks();
      notifyListeners();
      _processQueue();
    }
  }

  /// 清除已完成/已跳过的任务记录
  void clearFinished() {
    _tasks.removeWhere(
      (_, t) =>
          t.status == TaskStatus.completed || t.status == TaskStatus.skipped,
    );
    _saveTasks();
    notifyListeners();
  }

  /// 移除单个任务
  void removeTask(int bangumiId) {
    _tasks.remove(bangumiId);
    _saveTasks();
    notifyListeners();
  }

  // ============ 调度核心 ============

  /// 优先级调度：fetchDetail > downloadGrid > downloadLarge
  void _processQueue() {
    while (_activeWorkers < _maxConcurrent) {
      final task = _pickNextTask();
      if (task == null) break;

      task.status = TaskStatus.running;
      task.progress = 0.0;
      _activeWorkers++;
      notifyListeners();

      _runTask(task).then((_) {
        _activeWorkers--;
        _processQueue();
      });
    }
  }

  /// 按优先级选取下一个任务
  PoolTask? _pickNextTask() {
    // 优先级1：需要拉取详情的任务
    final detailTask = _tasks.values.where(
      (t) => t.status == TaskStatus.pending && t.phase == TaskPhase.fetchDetail,
    );
    if (detailTask.isNotEmpty) return detailTask.first;

    // 优先级2：需要下载 grid 的任务
    final gridTask = _tasks.values.where(
      (t) =>
          t.status == TaskStatus.pending && t.phase == TaskPhase.downloadGrid,
    );
    if (gridTask.isNotEmpty) return gridTask.first;

    // 优先级3：需要下载 large 的任务
    final largeTask = _tasks.values.where(
      (t) =>
          t.status == TaskStatus.pending && t.phase == TaskPhase.downloadLarge,
    );
    if (largeTask.isNotEmpty) return largeTask.first;

    return null;
  }

  /// 执行单个任务的当前阶段
  Future<void> _runTask(PoolTask task) async {
    try {
      switch (task.phase) {
        case TaskPhase.fetchDetail:
          await _executeFetchDetail(task);
        case TaskPhase.downloadGrid:
          await _executeDownloadGrid(task);
        case TaskPhase.downloadLarge:
          await _executeDownloadLarge(task);
        case TaskPhase.done:
          task.status = TaskStatus.completed;
          _saveTasks();
          notifyListeners();
      }
    } catch (e) {
      task.status = TaskStatus.failed;
      task.error = e.toString();
      _saveTasks();
      notifyListeners();
      debugPrint('任务失败 [${task.characterName}/${task.bangumiId}]: $e');
    }
  }

  /// 阶段1：拉取详情
  Future<void> _executeFetchDetail(PoolTask task) async {
    final dto = await _bangumiService.getCharacterDetail(task.bangumiId);

    if (dto == null) {
      task.status = TaskStatus.failed;
      task.error = '无法获取角色详情';
      _saveTasks();
      notifyListeners();
      return;
    }

    task.characterName = dto.displayName;
    task.gridUrl = dto.avatarGridUrl;
    task.largeUrl = dto.avatarLargeUrl;

    if (!dto.hasBirthday) {
      // 无生日 → 跳过，不入库
      task.hasBirthday = false;
      task.status = TaskStatus.skipped;
      task.phase = TaskPhase.done;
      _saveTasks();
      notifyListeners();
      return;
    }

    task.hasBirthday = true;
    task.detailDto = dto;

    // 调用回调入库
    if (onCharacterReady != null) {
      final characterId = await onCharacterReady!(dto);
      task.characterId = characterId;
    }

    task.detailDto = null; // 释放内存

    // 推进到图片下载阶段
    if (task.gridUrl != null) {
      task.phase = TaskPhase.downloadGrid;
      task.status = TaskStatus.pending;
    } else if (task.largeUrl != null) {
      task.phase = TaskPhase.downloadLarge;
      task.status = TaskStatus.pending;
    } else {
      task.phase = TaskPhase.done;
      task.status = TaskStatus.completed;
    }

    _saveTasks();
    notifyListeners();
  }

  /// 阶段2：下载 grid 图片
  Future<void> _executeDownloadGrid(PoolTask task) async {
    if (task.gridUrl == null) {
      // 无 grid → 跳到 large
      if (task.largeUrl != null) {
        task.phase = TaskPhase.downloadLarge;
        task.status = TaskStatus.pending;
      } else {
        task.phase = TaskPhase.done;
        task.status = TaskStatus.completed;
      }
      _saveTasks();
      notifyListeners();
      return;
    }

    final localPath = await _downloadFile(
      task.gridUrl!,
      task.bangumiId,
      'grid',
      onProgress: (received, total) {
        if (total > 0) {
          task.progress = received / total;
          notifyListeners();
        }
      },
    );

    task.gridLocalPath = localPath;
    task.progress = 1.0;

    // 通知回调（grid 完成即可在列表显示小图）
    if (task.characterId != null && localPath != null) {
      onImageReady?.call(task.characterId!, localPath, task.largeLocalPath);
    }

    // 推进到 large 阶段
    if (task.largeUrl != null) {
      task.phase = TaskPhase.downloadLarge;
      task.status = TaskStatus.pending;
    } else {
      task.phase = TaskPhase.done;
      task.status = TaskStatus.completed;
    }

    _saveTasks();
    notifyListeners();
  }

  /// 阶段3：下载 large 图片
  Future<void> _executeDownloadLarge(PoolTask task) async {
    if (task.largeUrl == null) {
      task.phase = TaskPhase.done;
      task.status = TaskStatus.completed;
      _saveTasks();
      notifyListeners();
      return;
    }

    final localPath = await _downloadFile(
      task.largeUrl!,
      task.bangumiId,
      'large',
      onProgress: (received, total) {
        if (total > 0) {
          task.progress = received / total;
          notifyListeners();
        }
      },
    );

    task.largeLocalPath = localPath;
    task.progress = 1.0;
    task.phase = TaskPhase.done;
    task.status = TaskStatus.completed;

    // 通知回调
    if (task.characterId != null && localPath != null) {
      onImageReady?.call(task.characterId!, task.gridLocalPath, localPath);
    }

    _saveTasks();
    notifyListeners();
  }

  /// 文件下载工具
  ///
  /// [bangumiId] 角色 ID，[type] 为 'grid' 或 'large'
  /// 命名规则：`{type}_{bangumiId}{ext}`，可跨会话确定性查找
  /// 下载前先检查文件是否已存在，存在则直接返回本地路径（避免重复下载）
  Future<String?> _downloadFile(
    String url,
    int bangumiId,
    String type, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final ext = path.extension(url);
      final safExt = ext.isNotEmpty ? ext : '.jpg';
      final fileName = '${type}_$bangumiId$safExt';
      final savePath = PathManager().getImagePath(fileName);

      // 文件已存在 → 跳过下载，直接返回本地路径
      if (File(savePath).existsSync()) {
        debugPrint('文件已存在，跳过下载: $fileName');
        return savePath;
      }

      await _dio.download(url, savePath, onReceiveProgress: onProgress);
      return savePath;
    } catch (e) {
      debugPrint('下载文件失败: $e');
      return null;
    }
  }

  // ============ 持久化 ============

  Future<void> _saveTasks() async {
    try {
      final file = File(_tasksFilePath);
      final jsonList = _tasks.values.map((t) => t.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('保存任务池失败: $e');
    }
  }

  Future<void> _loadTasks() async {
    try {
      final file = File(_tasksFilePath);
      if (!await file.exists()) return;
      final content = await file.readAsString();
      if (content.isEmpty) return;
      final List<dynamic> jsonList = jsonDecode(content);
      for (final json in jsonList) {
        final task = PoolTask.fromJson(json as Map<String, dynamic>);
        _tasks[task.bangumiId] = task;
      }
    } catch (e) {
      debugPrint('加载任务池失败: $e');
    }
  }
}
