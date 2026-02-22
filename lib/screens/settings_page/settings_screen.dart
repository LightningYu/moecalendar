import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:go_router/go_router.dart';
import 'package:moecalendar/config/app_info.dart';
import 'package:provider/provider.dart';
import '../../config/routes/app_routes.dart';
import '../../providers/character_provider.dart';
import '../../providers/theme_provider.dart';
import '../../config/design_constants.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
      ),
      body: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return ListView(
            children: [
              _buildThemeModeSection(context, themeProvider),
              const Divider(),
              _buildColorSection(context, themeProvider),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.tv),
                title: const Text('Bangumi 设置'),
                subtitle: const Text('登录、同步收藏'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.settingsBangumiPath),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.sync_alt),
                title: const Text('数据管理'),
                subtitle: const Text('导出、导入角色数据'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.dataSyncPath),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: const Text('清理图片缓存'),
                subtitle: const Text('清除网络图片的本地缓存'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showCacheCleanupDialog(context),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('关于应用'),
                subtitle: const Text('版本信息、开发者信息'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.aboutPath),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('开源声明'),
                subtitle: const Text('查看使用的开源项目'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => LicensePage(
                        applicationName: AppInfo.name,
                        applicationVersion: AppInfo.version,
                        applicationIcon: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Image.asset(
                            'assets/img/ico.webp',
                            width: 64,
                            height: 64,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCacheCleanupDialog(BuildContext context) {
    bool keepAddedCharacterImages = true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('清理图片缓存'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '将清除 CachedNetworkImage 下载的所有图片缓存，'
                    '下次浏览时会重新从网络加载。',
                  ),
                  const SizedBox(height: DesignConstants.spacing),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('保留已添加角色的图片'),
                    subtitle: const Text('跳过已添加的 Bangumi 角色头像'),
                    value: keepAddedCharacterImages,
                    onChanged: (v) {
                      setDialogState(() {
                        keepAddedCharacterImages = v ?? true;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await _performCacheCleanup(
                      context,
                      keepAddedCharacterImages,
                    );
                  },
                  child: const Text('清理'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _performCacheCleanup(
    BuildContext context,
    bool keepAddedCharacterImages,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (!keepAddedCharacterImages) {
        // 全部清除
        await DefaultCacheManager().emptyCache();
        messenger.showSnackBar(const SnackBar(content: Text('图片缓存已全部清除')));
      } else {
        // 收集已添加角色的图片 URL，预加载后再清除其余缓存
        final provider = Provider.of<CharacterProvider>(context, listen: false);
        final urlsToKeep = <String>{};
        for (final c in provider.bangumiCharacters) {
          if (c.gridAvatarPath != null &&
              c.gridAvatarPath!.startsWith('http')) {
            urlsToKeep.add(c.gridAvatarPath!);
          }
          if (c.largeAvatarPath != null &&
              c.largeAvatarPath!.startsWith('http')) {
            urlsToKeep.add(c.largeAvatarPath!);
          }
          if (c.avatarPath != null && c.avatarPath!.startsWith('http')) {
            urlsToKeep.add(c.avatarPath!);
          }
        }

        // 先获取已添加角色图片的缓存文件信息
        final cacheManager = DefaultCacheManager();
        final cachedFiles = <FileInfo>[];
        for (final url in urlsToKeep) {
          final info = await cacheManager.getFileFromCache(url);
          if (info != null) {
            cachedFiles.add(info);
          }
        }

        // 清除全部缓存
        await cacheManager.emptyCache();

        // 重新下载已添加角色的图片缓存
        for (final url in urlsToKeep) {
          try {
            await cacheManager.downloadFile(url);
          } catch (_) {
            // 忽略单张图片下载失败
          }
        }

        messenger.showSnackBar(
          SnackBar(content: Text('缓存已清理，保留了 ${urlsToKeep.length} 张已添加角色的图片')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('清理缓存失败: $e')));
    }
  }

  Widget _buildThemeModeSection(
    BuildContext context,
    ThemeProvider themeProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            '主题模式',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        RadioListTile<ThemeMode>(
          title: const Text('跟随系统'),
          value: ThemeMode.system,
          groupValue: themeProvider.themeMode,
          onChanged: (value) => themeProvider.setThemeMode(value!),
        ),
        RadioListTile<ThemeMode>(
          title: const Text('浅色模式'),
          value: ThemeMode.light,
          groupValue: themeProvider.themeMode,
          onChanged: (value) => themeProvider.setThemeMode(value!),
        ),
        RadioListTile<ThemeMode>(
          title: const Text('深色模式'),
          value: ThemeMode.dark,
          groupValue: themeProvider.themeMode,
          onChanged: (value) => themeProvider.setThemeMode(value!),
        ),
      ],
    );
  }

  Widget _buildColorSection(BuildContext context, ThemeProvider themeProvider) {
    final List<Color> colors = [
      Colors.pink,
      Colors.red,
      Colors.orange,
      Colors.amber,
      Colors.green,
      Colors.teal,
      Colors.blue,
      Colors.indigo,
      Colors.purple,
      Colors.brown,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(DesignConstants.spacing),
          child: const Text(
            '主题颜色',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignConstants.spacing,
          ),
          child: Wrap(
            spacing: DesignConstants.spacingMd,
            runSpacing: DesignConstants.spacingMd,
            children: colors.map((color) {
              return GestureDetector(
                onTap: () => themeProvider.setSeedColor(color),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          themeProvider.seedColor.toARGB32() == color.toARGB32()
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: themeProvider.seedColor.toARGB32() == color.toARGB32()
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: DesignConstants.spacing),
      ],
    );
  }
}
