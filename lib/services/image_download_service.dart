import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../utils/path_manager.dart';

/// 单个下载任务的状态
enum DownloadStatus { pending, downloading, completed, failed }

/// 单个下载任务
class DownloadTask {
  final String characterId;
  final String characterName;
  final String? gridUrl;
  final String? largeUrl;

  DownloadStatus status;
  double progress; // 0.0 ~ 1.0
  String? gridLocalPath;
  String? largeLocalPath;
  String? error;

  DownloadTask({
    required this.characterId,
    required this.characterName,
    this.gridUrl,
    this.largeUrl,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.gridLocalPath,
    this.largeLocalPath,
  });

  /// 序列化为 JSON（用于持久化）
  Map<String, dynamic> toJson() => {
    'characterId': characterId,
    'characterName': characterName,
    'gridUrl': gridUrl,
    'largeUrl': largeUrl,
    'status': status.index,
    'gridLocalPath': gridLocalPath,
    'largeLocalPath': largeLocalPath,
  };

  /// 从 JSON 反序列化
  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    final statusIndex = json['status'] as int? ?? 0;
    return DownloadTask(
      characterId: json['characterId'] as String,
      characterName: json['characterName'] as String,
      gridUrl: json['gridUrl'] as String?,
      largeUrl: json['largeUrl'] as String?,
      status: DownloadStatus.values[statusIndex.clamp(0, 3)],
      gridLocalPath: json['gridLocalPath'] as String?,
      largeLocalPath: json['largeLocalPath'] as String?,
    );
  }

  /// 是否还有未完成的下载
  bool get hasUnfinishedWork {
    if (gridUrl != null && gridLocalPath == null) return true;
    if (largeUrl != null && largeLocalPath == null) return true;
    return false;
  }
}

/// 下载阶段：先全员 grid，再全员 large
enum _DownloadPhase { grid, large }

/// 图片后台下载服务
///
/// 策略：先并发下载所有任务的 grid 小图，全部完成后再并发下载 large 大图。
/// 最多同时进行 [_maxConcurrent] 个网络连接。
/// 任务持久化到 JSON 文件，应用重启后可恢复未完成的下载。
class ImageDownloadService extends ChangeNotifier {
  static final ImageDownloadService _instance =
      ImageDownloadService._internal();
  factory ImageDownloadService() => _instance;
  ImageDownloadService._internal();

  final Dio _dio = Dio();

  /// 所有下载任务（按 characterId 索引）
  final Map<String, DownloadTask> _tasks = {};

  /// 图片下载回调：每下载完一张就回调一次
  /// (characterId, gridLocalPath?, largeLocalPath?)
  void Function(String characterId, String? gridPath, String? largePath)?
  onImageReady;

  /// 最大并发下载数
  static const int _maxConcurrent = 3;

  /// 当前活跃 worker 数量
  int _activeWorkers = 0;
  bool _initialized = false;

  /// 任务持久化文件路径
  String get _tasksFilePath =>
      path.join(PathManager().documentsPath, 'download_tasks.json');

  /// 获取某个角色的下载任务
  DownloadTask? getTask(String characterId) => _tasks[characterId];

  /// 获取角色的已下载 grid 本地路径（缓存优先）
  String? getCachedGridPath(String characterId) =>
      _tasks[characterId]?.gridLocalPath;

  /// 获取角色的已下载 large 本地路径（缓存优先）
  String? getCachedLargePath(String characterId) =>
      _tasks[characterId]?.largeLocalPath;

  /// 获取用于列表显示的最佳本地路径（grid 优先，降级 large）
  String? getCachedListAvatar(String characterId) {
    final task = _tasks[characterId];
    if (task == null) return null;
    return task.gridLocalPath ?? task.largeLocalPath;
  }

  /// 获取用于详情显示的最佳本地路径（large 优先，降级 grid）
  String? getCachedDetailAvatar(String characterId) {
    final task = _tasks[characterId];
    if (task == null) return null;
    return task.largeLocalPath ?? task.gridLocalPath;
  }

  /// 是否有正在进行的下载
  bool get hasActiveDownloads => _tasks.values.any(
    (t) =>
        t.status == DownloadStatus.pending ||
        t.status == DownloadStatus.downloading,
  );

  /// 当前活跃下载数量
  int get activeDownloadCount => _tasks.values
      .where(
        (t) =>
            t.status == DownloadStatus.pending ||
            t.status == DownloadStatus.downloading,
      )
      .length;

  /// 初始化：从磁盘恢复未完成的任务
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadTasks();
    // 将之前 downloading/failed 状态的任务重置为 pending 以便重新下载
    for (final task in _tasks.values) {
      if (task.status == DownloadStatus.downloading ||
          task.status == DownloadStatus.failed) {
        task.status = DownloadStatus.pending;
        task.progress = 0.0;
        task.error = null;
      }
      // 已完成但仍有未下载的文件（如之前只完成了 grid）
      if (task.status == DownloadStatus.completed && task.hasUnfinishedWork) {
        task.status = DownloadStatus.pending;
        task.progress = 0.0;
      }
    }
    // 移除已真正完成的任务
    _tasks.removeWhere(
      (_, t) => t.status == DownloadStatus.completed && !t.hasUnfinishedWork,
    );
    if (_tasks.values.any((t) => t.status == DownloadStatus.pending)) {
      notifyListeners();
      _processQueue();
    }
  }

  /// 将角色的图片加入下载队列
  void enqueue({
    required String characterId,
    required String characterName,
    String? gridUrl,
    String? largeUrl,
  }) {
    if (gridUrl == null && largeUrl == null) return;

    // 已经有成功完成且无未完成工作的任务就不重复下载
    final existing = _tasks[characterId];
    if (existing != null &&
        existing.status == DownloadStatus.completed &&
        !existing.hasUnfinishedWork) {
      return;
    }

    _tasks[characterId] = DownloadTask(
      characterId: characterId,
      characterName: characterName,
      gridUrl: gridUrl,
      largeUrl: largeUrl,
    );
    _saveTasks();
    notifyListeners();
    _processQueue();
  }

  /// 重试失败的任务
  void retry(String characterId) {
    final task = _tasks[characterId];
    if (task == null || task.status != DownloadStatus.failed) return;
    task.status = DownloadStatus.pending;
    task.progress = 0.0;
    task.error = null;
    _saveTasks();
    notifyListeners();
    _processQueue();
  }

  /// 移除已完成的任务记录（清理内存和磁盘）
  void clearCompleted() {
    _tasks.removeWhere(
      (_, t) => t.status == DownloadStatus.completed && !t.hasUnfinishedWork,
    );
    _saveTasks();
    notifyListeners();
  }

  /// 调度队列：先并发下载所有任务的 grid，grid 全部完成后再下 large
  void _processQueue() {
    // 判断当前阶段：是否还有任何任务的 grid 未完成
    final hasGridPending = _tasks.values.any(
      (t) =>
          t.gridUrl != null &&
          t.gridLocalPath == null &&
          (t.status == DownloadStatus.pending ||
              t.status == DownloadStatus.downloading),
    );
    final phase = hasGridPending ? _DownloadPhase.grid : _DownloadPhase.large;

    while (_activeWorkers < _maxConcurrent) {
      // 根据阶段选出候选任务
      final pending = _tasks.values.where((t) {
        if (t.status != DownloadStatus.pending) return false;
        if (phase == _DownloadPhase.grid) {
          // grid 阶段：选 grid 未完成的任务
          return t.gridUrl != null && t.gridLocalPath == null;
        } else {
          // large 阶段：选 large 未完成（且 grid 已完成或无 grid）的任务
          return t.largeUrl != null &&
              t.largeLocalPath == null &&
              (t.gridUrl == null || t.gridLocalPath != null);
        }
      }).toList();

      if (pending.isEmpty) break;

      final task = pending.first;
      task.status = DownloadStatus.downloading;
      task.progress = 0.0;
      _activeWorkers++;
      notifyListeners();

      _runWorker(task, phase).then((_) {
        _activeWorkers--;
        _processQueue();
      });
    }
  }

  Future<void> _runWorker(DownloadTask task, _DownloadPhase phase) async {
    try {
      if (phase == _DownloadPhase.grid) {
        // 只下载 grid
        task.gridLocalPath = await _downloadFile(
          task.gridUrl!,
          task.characterId,
          suffix: '_grid',
          onProgress: (received, total) {
            if (total > 0) {
              task.progress = received / total;
              notifyListeners();
            }
          },
        );
        task.progress = 1.0;
        _saveTasks();
        notifyListeners();

        // Grid 完成立即回调，UI 马上显示小图
        if (task.gridLocalPath != null) {
          onImageReady?.call(
            task.characterId,
            task.gridLocalPath,
            task.largeLocalPath,
          );
        }

        // 如果没有 large 需要下载，则直接标记完成
        if (task.largeUrl == null) {
          task.status = DownloadStatus.completed;
          _saveTasks();
          notifyListeners();
        } else {
          // 还需要 large，重新置为 pending 等待 large 阶段调度
          task.status = DownloadStatus.pending;
          notifyListeners();
        }
      } else {
        // 只下载 large
        task.largeLocalPath = await _downloadFile(
          task.largeUrl!,
          task.characterId,
          suffix: '_large',
          onProgress: (received, total) {
            if (total > 0) {
              task.progress = received / total;
              notifyListeners();
            }
          },
        );
        task.progress = 1.0;
        task.status = DownloadStatus.completed;
        _saveTasks();
        notifyListeners();

        if (task.largeLocalPath != null) {
          onImageReady?.call(
            task.characterId,
            task.gridLocalPath,
            task.largeLocalPath,
          );
        }
      }
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.error = e.toString();
      _saveTasks();
      notifyListeners();
      debugPrint('图片下载失败 [${task.characterName}]: $e');
    }
  }

  Future<String?> _downloadFile(
    String url,
    String id, {
    String suffix = '',
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final ext = path.extension(url);
      final fileName = 'avatar_$id$suffix$ext';
      final savePath = PathManager().getImagePath(fileName);

      await _dio.download(url, savePath, onReceiveProgress: onProgress);
      return savePath;
    } catch (e) {
      debugPrint('Error downloading image: $e');
      return null;
    }
  }

  // ============ 任务持久化 ============

  Future<void> _saveTasks() async {
    try {
      final file = File(_tasksFilePath);
      final jsonList = _tasks.values.map((t) => t.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('保存下载任务失败: $e');
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
        final task = DownloadTask.fromJson(json as Map<String, dynamic>);
        _tasks[task.characterId] = task;
      }
    } catch (e) {
      debugPrint('加载下载任务失败: $e');
    }
  }
}
