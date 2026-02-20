import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/character_provider.dart';
import '../../services/task_pool_service.dart';

/// 任务池页面：与人物页同级 Tab
class TaskPoolTab extends StatelessWidget {
  const TaskPoolTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('下载池'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              final taskPool = TaskPoolService();
              switch (value) {
                case 'retry_all':
                  taskPool.retryAllFailed();
                case 'clear_finished':
                  taskPool.clearFinished();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'retry_all', child: Text('重试所有失败')),
              const PopupMenuItem(
                value: 'clear_finished',
                child: Text('清除已完成'),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<CharacterProvider>(
        builder: (context, provider, _) {
          final taskPool = provider.taskPoolService;
          final tasks = taskPool.allTasks;

          if (tasks.isEmpty) {
            return _buildEmptyState(context);
          }

          final stats = taskPool.stats;

          return Column(
            children: [
              // 统计概览
              _buildStatsBar(context, stats),
              const Divider(height: 1),
              // 任务列表
              Expanded(
                child: ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return _TaskListItem(task: task);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_download_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('暂无下载任务', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '添加 Bangumi 角色时会自动创建下载任务\n任务会获取角色详情并下载头像',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBar(
    BuildContext context,
    ({int total, int completed, int failed, int skipped, int active}) stats,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _StatChip(
            label: '进行中',
            count: stats.active,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          _StatChip(label: '完成', count: stats.completed, color: Colors.green),
          const SizedBox(width: 8),
          _StatChip(label: '跳过', count: stats.skipped, color: Colors.orange),
          const SizedBox(width: 8),
          _StatChip(
            label: '失败',
            count: stats.failed,
            color: theme.colorScheme.error,
          ),
          const Spacer(),
          Text(
            '共 ${stats.total}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _TaskListItem extends StatelessWidget {
  final PoolTask task;

  const _TaskListItem({required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (icon, iconColor) = switch (task.status) {
      TaskStatus.pending => (Icons.hourglass_empty, theme.hintColor),
      TaskStatus.running => (Icons.sync, theme.colorScheme.primary),
      TaskStatus.completed => (Icons.check_circle, Colors.green),
      TaskStatus.failed => (Icons.error, theme.colorScheme.error),
      TaskStatus.skipped => (Icons.skip_next, Colors.orange),
    };

    return ListTile(
      leading: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: iconColor, size: 28),
          if (task.status == TaskStatus.running && task.progress > 0)
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                value: task.progress,
                strokeWidth: 2,
                color: iconColor,
              ),
            ),
        ],
      ),
      title: Text(
        task.characterName.isNotEmpty
            ? task.characterName
            : 'Bangumi #${task.bangumiId}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        task.statusText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: task.status == TaskStatus.failed
              ? theme.colorScheme.error
              : null,
        ),
      ),
      trailing: _buildTrailing(context),
    );
  }

  Widget? _buildTrailing(BuildContext context) {
    final taskPool = TaskPoolService();

    switch (task.status) {
      case TaskStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '重试',
              onPressed: () => taskPool.retry(task.bangumiId),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: '移除',
              onPressed: () => taskPool.removeTask(task.bangumiId),
            ),
          ],
        );
      case TaskStatus.completed:
      case TaskStatus.skipped:
        return IconButton(
          icon: const Icon(Icons.close),
          tooltip: '移除',
          onPressed: () => taskPool.removeTask(task.bangumiId),
        );
      default:
        return null;
    }
  }
}
