import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/character_provider.dart';
import '../services/import_intent_service.dart';
import '../services/data_sync_service.dart';
import 'settings_page/data_sync_screen.dart';

class MainScreen extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainScreen({super.key, required this.navigationShell});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  StreamSubscription<String>? _intentSub;

  @override
  void initState() {
    super.initState();
    // 监听热启动时传入的 JSON
    _intentSub = ImportIntentService.onJsonReceived.listen(_handleImportJson);
    // 检查冷启动时的 JSON
    _checkInitialJson();
  }

  Future<void> _checkInitialJson() async {
    final json = await ImportIntentService.getInitialJson();
    if (json != null && mounted) {
      _handleImportJson(json);
    }
  }

  void _handleImportJson(String json) {
    if (!mounted) return;
    // 验证是否可解析
    final syncService = DataSyncService();
    final parsed = syncService.parseJson(json);
    if (parsed == null || parsed.isEmpty) return;

    // 跳转到数据管理页面并传入 JSON
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DataSyncScreen(initialImportJson: json),
      ),
    );
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    super.dispose();
  }

  void _goBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, child) {
        final taskPool = provider.taskPoolService;
        final activeCount = taskPool.activeTaskCount;

        return Scaffold(
          body: widget.navigationShell,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: widget.navigationShell.currentIndex,
            onTap: _goBranch,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.cake),
                label: '生日',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: '人物',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: activeCount > 0,
                  label: Text('$activeCount'),
                  child: const Icon(Icons.cloud_download),
                ),
                label: '下载池',
              ),
            ],
          ),
        );
      },
    );
  }
}
