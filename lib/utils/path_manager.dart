import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../config/app_info.dart';

class PathManager {
  static final PathManager _instance = PathManager._internal();
  factory PathManager() => _instance;
  PathManager._internal();

  Directory? _documentsDir;

  Future<void> init() async {
    _documentsDir = await getApplicationDocumentsDirectory();
  }

  String get documentsPath {
    if (_documentsDir == null) {
      throw Exception('PathManager not initialized');
    }
    return _documentsDir!.path;
  }

  String get dataFilePath => path.join(documentsPath, AppInfo.dataFileName);

  String get imagesPath => path.join(documentsPath, AppInfo.imageFolderName);

  Future<void> ensureImagesDirExists() async {
    final dir = Directory(imagesPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  String getImagePath(String fileName) {
    return path.join(imagesPath, fileName);
  }
}
