import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moecalendar/config/app_info.dart';
import 'package:provider/provider.dart';
import '../../config/routes/app_routes.dart';
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
