import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/character_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../services/permission_service.dart';
import '../config/routes/app_routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;

  // Step 1: Birthday
  DateTime? _selectedDate;
  bool _isLunar = false;

  // Step 2: Theme
  Color _selectedColor = Colors.blue;
  ThemeMode _selectedThemeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
  }

  bool get _canGoNext {
    switch (_currentStep) {
      case 0: // Welcome
        return true;
      case 1: // Birthday
        return _selectedDate != null;
      case 2: // Theme
        return true;
      case 3: // Bangumi
        return true;
      default:
        return false;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String _getDateText() {
    if (_selectedDate == null) return '';
    return DateFormat('yyyy-MM-dd').format(_selectedDate!);
  }

  Future<void> _saveAndComplete() async {
    if (_selectedDate == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先设置你的生日')));
      }
      setState(() => _currentStep = 1);
      return;
    }

    final charProvider = Provider.of<CharacterProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    try {
      // Save Birthday
      await charProvider.upsertSelfCharacter(
        birthday: _selectedDate!,
        isLunar: _isLunar,
        displayName: '你',
      );
      await PermissionService.setSelfBirthdaySet(true);

      // Save Theme (Already updated in real-time for preview, but ensure it's saved)
      await themeProvider.setSeedColor(_selectedColor);
      await themeProvider.setThemeMode(_selectedThemeMode);

      // Mark Completed
      await PermissionService.setOnboardingCompleted();

      if (mounted) {
        context.go(AppRoutes.birthTab);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    }
  }

  void _onStepContinue() {
    if (_currentStep < 3) {
      if (_canGoNext) {
        setState(() => _currentStep++);
      } else {
        if (_currentStep == 1 && _selectedDate == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('请选择出生日期')));
        }
      }
    } else {
      _saveAndComplete();
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('初始设置'), centerTitle: true),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: _onStepContinue,
        onStepCancel: _onStepCancel,
        controlsBuilder: (context, details) {
          final isLastStep = _currentStep == 3;
          return Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: Row(
              children: [
                FilledButton(
                  onPressed: details.onStepContinue,
                  child: Text(isLastStep ? '完成设置' : '下一步'),
                ),
                const SizedBox(width: 12),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('上一步'),
                  ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('欢迎'),
            subtitle: const Text('了解应用功能'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: _buildWelcomeStep(theme),
          ),
          Step(
            title: const Text('设置生日'),
            subtitle: Text(_selectedDate != null ? '已设置' : '必填项'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: _buildBirthdayStep(theme),
          ),
          Step(
            title: const Text('个性化主题'),
            subtitle: const Text('选择喜欢的颜色'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: _buildThemeStep(theme),
          ),
          Step(
            title: const Text('Bangumi 集成'),
            subtitle: const Text('可选'),
            isActive: _currentStep >= 3,
            state: StepState.indexed,
            content: _buildBangumiStep(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          // child: Icon(Icons.cake, size: 80, color: theme.colorScheme.primary),
          child: Image.asset('assets/img/ico.webp', width: 128, height: 128),
        ),
        const SizedBox(height: 24),
        Text(
          '''欢迎使用萌历
          Moe Calendar''',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        const Text('这个应用可以帮你记住重要的生日，并在特殊的日子给你惊喜。(其实没有)'),
        const SizedBox(height: 24),
        _buildFeatureItem(
          theme,
          Icons.notifications_active_outlined,
          '生日提醒',
          '记录你和朋友的生日',
        ),
        const SizedBox(height: 12),
        _buildFeatureItem(
          theme,
          Icons.cloud_sync_outlined,
          'Bangumi 集成',
          '从 Bangumi 导入喜欢的角色',
        ),
        const SizedBox(height: 12),
        _buildFeatureItem(
          theme,
          Icons.color_lens_outlined,
          '个性化主题',
          '随心定制界面风格',
        ),
        const SizedBox(height: 12),
        _buildFeatureItem(
          theme,
          Icons.calendar_today_outlined,
          '一键导出',
          '导出为系统日历事件',
        ),
        const SizedBox(height: 12),
        _buildFeatureItem(theme, Icons.tv_outlined, 'BILBIL搜索:雷霆宇宇侠', '别笑'),
        const SizedBox(height: 12),
        _buildFeatureItem(
          theme,
          Icons.error_outlined,
          '特别注意',
          '''1.本应用免费无广告,若有广告或付费项既为盗版
2.本应用不收集也没能力收集用户的个人信息(拜托服务器很贵的)
3.本应用不必需登录
        ''',
        ),
      ],
    );
  }

  Widget _buildFeatureItem(
    ThemeData theme,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBirthdayStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('设置你的生日，应用会为你准备专属的生日页面。'),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(77),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.calendar_month,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('出生日期'),
                subtitle: Text(
                  _selectedDate != null ? _getDateText() : '点击选择日期',
                ),
                trailing: _selectedDate != null
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.chevron_right),
                onTap: () => _selectDate(context),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                secondary: const Icon(Icons.brightness_2),
                title: const Text('农历生日'),
                subtitle: const Text('上方日期将被视为农历日期'),
                value: _isLunar,
                onChanged: (val) => setState(() => _isLunar = val),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeStep(ThemeData theme) {
    final colors = [
      Colors.blue,
      Colors.purple,
      Colors.pink,
      Colors.red,
      Colors.orange,
      Colors.amber,
      Colors.green,
      Colors.teal,
      Colors.cyan,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('选择你喜欢的颜色和主题模式。'),
        const SizedBox(height: 16),
        Text('主题颜色', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((color) {
            final isSelected = _selectedColor == color;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedColor = color);
                Provider.of<ThemeProvider>(
                  context,
                  listen: false,
                ).setSeedColor(color);
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(
                          color: theme.colorScheme.onSurface,
                          width: 2.5,
                        )
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Text('主题模式', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto),
              label: Text('跟随系统'),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode),
              label: Text('浅色'),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode),
              label: Text('深色'),
            ),
          ],
          selected: {_selectedThemeMode},
          onSelectionChanged: (selected) {
            setState(() => _selectedThemeMode = selected.first);
            Provider.of<ThemeProvider>(
              context,
              listen: false,
            ).setThemeMode(_selectedThemeMode);
          },
        ),
      ],
    );
  }

  Widget _buildBangumiStep(ThemeData theme) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final isLoggedIn = authProvider.isLoggedIn;
        final isLoading = authProvider.isLoading;
        final user = authProvider.user;
        final avatarUrl = user?.avatar.large;
        final hasAvatar =
            isLoggedIn && avatarUrl != null && avatarUrl.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bangumi 是一个动漫、游戏追踪平台。连接后可以快速导入你收藏的角色生日。\n\nPS:不登录也可以正常使用搜索添加角色的功能,建议之前有账号的可以登录',
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(77),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: isLoggedIn
                              ? Colors.green.withAlpha(51)
                              : theme.colorScheme.surfaceContainerHigh,
                          backgroundImage: hasAvatar && !isLoading
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: isLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : (!hasAvatar
                                    ? Icon(
                                        isLoggedIn
                                            ? Icons.check
                                            : Icons.person_outline,
                                        color: isLoggedIn
                                            ? Colors.green
                                            : theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                      )
                                    : null),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isLoading
                                    ? '正在连接...'
                                    : (isLoggedIn
                                          ? (user?.nickname ?? '已登录')
                                          : '未登录 Bangumi'),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                isLoading
                                    ? '请稍候'
                                    : (isLoggedIn ? '已准备好导入数据' : '登录以同步收藏'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: isLoggedIn
                          ? OutlinedButton(
                              onPressed: isLoading
                                  ? null
                                  : () => authProvider.logout(),
                              child: const Text('退出登录'),
                            )
                          : FilledButton.tonal(
                              onPressed: isLoading
                                  ? null
                                  : () => authProvider.startLogin(),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('前往登录'),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
