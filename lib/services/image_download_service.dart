import 'dart:async';
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
  });
}

/// 图片后台下载服务
///
/// 提供队列式的后台图片下载，不阻塞 UI。
/// 下载完成后通过回调通知 CharacterProvider 更新角色的本地路径。
class ImageDownloadService extends ChangeNotifier {
  static final ImageDownloadService _instance =
      ImageDownloadService._internal();
  factory ImageDownloadService() => _instance;
  ImageDownloadService._internal();

  final Dio _dio = Dio();

  /// 所有下载任务（按 characterId 索引）
  final Map<String, DownloadTask> _tasks = {};

  /// 下载完成回调：(characterId, gridLocalPath, largeLocalPath)
  void Function(String characterId, String? gridPath, String? largePath)?
  onDownloadComplete;

  bool _isProcessing = false;

  /// 获取某个角色的下载任务
  DownloadTask? getTask(String characterId) => _tasks[characterId];

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

  /// 将角色的图片加入下载队列
  void enqueue({
    required String characterId,
    required String characterName,
    String? gridUrl,
    String? largeUrl,
  }) {
    if (gridUrl == null && largeUrl == null) return;

    // 已经有成功的任务就不重复下载
    final existing = _tasks[characterId];
    if (existing != null && existing.status == DownloadStatus.completed) return;

    _tasks[characterId] = DownloadTask(
      characterId: characterId,
      characterName: characterName,
      gridUrl: gridUrl,
      largeUrl: largeUrl,
    );
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
    notifyListeners();
    _processQueue();
  }

  /// 移除已完成的任务记录（清理内存）
  void clearCompleted() {
    _tasks.removeWhere((_, t) => t.status == DownloadStatus.completed);
    notifyListeners();
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    while (true) {
      final pending = _tasks.values
          .where((t) => t.status == DownloadStatus.pending)
          .toList();
      if (pending.isEmpty) break;

      final task = pending.first;
      task.status = DownloadStatus.downloading;
      task.progress = 0.0;
      notifyListeners();

      try {
        int totalExpected = 0;
        if (task.gridUrl != null) totalExpected++;
        if (task.largeUrl != null) totalExpected++;
        int completedFiles = 0;

        // 下载 grid 图片
        if (task.gridUrl != null) {
          task.gridLocalPath = await _downloadFile(
            task.gridUrl!,
            task.characterId,
            suffix: '_grid',
            onProgress: (received, total) {
              if (total > 0 && totalExpected > 0) {
                final fileProgress = received / total;
                task.progress = (completedFiles + fileProgress) / totalExpected;
                notifyListeners();
              }
            },
          );
          completedFiles++;
          task.progress = completedFiles / totalExpected;
          notifyListeners();
        }

        // 下载 large 图片
        if (task.largeUrl != null) {
          task.largeLocalPath = await _downloadFile(
            task.largeUrl!,
            task.characterId,
            suffix: '_large',
            onProgress: (received, total) {
              if (total > 0 && totalExpected > 0) {
                final fileProgress = received / total;
                task.progress = (completedFiles + fileProgress) / totalExpected;
                notifyListeners();
              }
            },
          );
          completedFiles++;
          task.progress = 1.0;
          notifyListeners();
        }

        task.status = DownloadStatus.completed;
        task.progress = 1.0;
        notifyListeners();

        // 通知完成
        onDownloadComplete?.call(
          task.characterId,
          task.gridLocalPath,
          task.largeLocalPath,
        );
      } catch (e) {
        task.status = DownloadStatus.failed;
        task.error = e.toString();
        notifyListeners();
        debugPrint('图片下载失败 [${task.characterName}]: $e');
      }
    }

    _isProcessing = false;
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
}
