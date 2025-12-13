import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/main_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/birthday_page/birthday_tab.dart';
import '../screens/birthday_page/character_tab.dart';
import '../screens/birthday_page/birthday_grid_screen.dart';
import '../screens/birthday_page/birthday_detail_screen.dart';
import '../screens/char_page/character_detail_screen.dart';
import '../screens/add_char_page/add_bangumi_character_screen.dart';
import '../screens/add_char_page/add_manual_character_screen.dart';
import '../screens/add_char_page/add_self_character_screen.dart';
import '../screens/add_char_page/edit_self_character_screen.dart';
import '../screens/congratulate_page/congratulation_screen.dart';
import '../screens/congratulate_page/congratulation_character_screen.dart';
import '../screens/settings_page/settings_screen.dart';
import '../screens/settings_page/bangumi_settings_screen.dart';
import '../screens/settings_page/profile_screen.dart';
import '../screens/settings_page/about_screen.dart';
import '../models/character_model.dart';
import '../config/routes/app_routes.dart';
import '../services/permission_service.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

/// 检查是否需要显示引导页
Future<String?> _redirectLogic(
  BuildContext context,
  GoRouterState state,
) async {
  final isOnboardingCompleted = await PermissionService.isOnboardingCompleted();
  final isOnboardingRoute = state.matchedLocation == AppRoutes.onboarding;

  // 如果未完成引导且不在引导页，重定向到引导页
  if (!isOnboardingCompleted && !isOnboardingRoute) {
    return AppRoutes.onboarding;
  }

  // 如果已完成引导且在引导页，重定向到主页
  if (isOnboardingCompleted && isOnboardingRoute) {
    return AppRoutes.birthTab;
  }

  return null;
}

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: AppRoutes.birthTab,
  redirect: _redirectLogic,
  routes: [
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/oauth/callback',
      builder: (context, state) => const AuthCallbackScreen(),
    ),
    GoRoute(
      path: '/callback',
      builder: (context, state) => const AuthCallbackScreen(),
    ),
    GoRoute(
      path: AppRoutes.congratulate, // Legacy/Self
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final character = state.extra as Character;
        return CongratulationScreen(character: character);
      },
    ),
    GoRoute(
      path: AppRoutes.congratulateCharacter,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final characters = state.extra as List<Character>;
        return CongratulationCharacterScreen(characters: characters);
      },
    ),
    GoRoute(
      path: AppRoutes.settings,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SettingsScreen(),
      routes: [
        GoRoute(
          path: AppRoutes.settingsBangumi,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const BangumiSettingsScreen(),
        ),
        GoRoute(
          path: AppRoutes.profile,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: AppRoutes.about,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const AboutScreen(),
        ),
      ],
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainScreen(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.birthTab,
              builder: (context, state) {
                final targetCharacter = state.extra as Character?;
                return BirthdayTab(targetCharacter: targetCharacter);
              },
              routes: [
                GoRoute(
                  path: 'grid',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const BirthdayGridScreen(),
                ),
                GoRoute(
                  path: AppRoutes.detail,
                  parentNavigatorKey: _rootNavigatorKey, // 全屏显示
                  builder: (context, state) {
                    final character = state.extra as Character;
                    return BirthdayDetailScreen(character: character);
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.characterTab,
              builder: (context, state) => const CharacterTab(),
              routes: [
                GoRoute(
                  path: AppRoutes.detail,
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final character = state.extra as Character;
                    return CharacterDetailScreen.fromLocal(
                      character: character,
                    );
                  },
                ),
                GoRoute(
                  path: AppRoutes.addManual,
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const AddManualCharacterScreen(),
                ),
                GoRoute(
                  path: AppRoutes.addBangumi,
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) =>
                      const AddBangumiCharacterScreen(),
                ),
                GoRoute(
                  path: AppRoutes.addSelf,
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const AddSelfCharacterScreen(),
                ),
                GoRoute(
                  path: AppRoutes.editSelf,
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final character = state.extra as ManualCharacter;
                    return EditSelfCharacterScreen(character: character);
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

class AuthCallbackScreen extends StatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  @override
  void initState() {
    super.initState();
    // 使用 addPostFrameCallback 确保在构建完成后再访问 context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleCallback();
    });
  }

  Future<void> _handleCallback() async {
    if (!mounted) return;
    final state = GoRouterState.of(context);
    final code = state.uri.queryParameters['code'];

    if (code != null) {
      try {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        await auth.handleAuthCallback(code);
        if (mounted) {
          context.go(AppRoutes.settings);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('登录失败: $e')));
          context.go(AppRoutes.settings);
        }
      }
    } else {
      if (mounted) {
        context.go(AppRoutes.settings);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在登录...'),
          ],
        ),
      ),
    );
  }
}
