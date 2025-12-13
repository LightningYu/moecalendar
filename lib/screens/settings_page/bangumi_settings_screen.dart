import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/routes/app_routes.dart';

class BangumiSettingsScreen extends StatelessWidget {
  const BangumiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bangumi 设置')),
      body: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          return ListView(
            children: [
              _buildUserSection(context, auth),
              const Divider(),
              // Future settings can go here
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserSection(BuildContext context, AuthProvider auth) {
    if (auth.isLoading) {
      return const ListTile(
        leading: CircleAvatar(child: CircularProgressIndicator()),
        title: Text('登录中...'),
      );
    }

    if (auth.isLoggedIn) {
      final user = auth.user!;
      return ListTile(
        leading: CircleAvatar(
          backgroundImage: NetworkImage(user.avatar.medium),
        ),
        title: Text(user.nickname),
        subtitle: Text('@${user.username}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(AppRoutes.profilePath),
      );
    } else {
      return ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: const Text('登录 Bangumi'),
        subtitle: const Text('同步你的收藏'),
        trailing: const Icon(Icons.login),
        onTap: () => auth.startLogin(),
      );
    }
  }
}
