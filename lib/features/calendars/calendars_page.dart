import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/entities/calendar.dart';
import '../sync/sync_providers.dart';
import '../tasks/task_providers.dart';

/// 日历管理页：列出已配置日历、刷新远端、开关同步。
class CalendarsPage extends ConsumerWidget {
  const CalendarsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarsAsync = ref.watch(calendarListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('日历'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              try {
                final repo = ref.read(calendarRepositoryProvider);
                await repo.refreshFromRemote();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已从远端刷新日历列表')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('刷新失败：$e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: calendarsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  const Text('尚未配置日历'),
                  const SizedBox(height: 8),
                  const Text('请先在「设置」中配置 CalDAV 账户'),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _CalendarTile(calendar: list[i]),
          );
        },
      ),
    );
  }
}

class _CalendarTile extends ConsumerWidget {
  const _CalendarTile({required this.calendar});

  final Calendar calendar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = _parseColor(calendar.color);
    final tasksAsync = ref.watch(taskListProvider);
    final taskCount = tasksAsync.when(
      data: (tasks) => tasks.where((t) => t.calendarUrl == calendar.url).length,
      loading: () => null,
      error: (_, _) => null,
    );

    return SwitchListTile(
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.calendar_month,
          color: _foregroundColor(color),
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              calendar.displayName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (taskCount != null)
            _MetaChip(label: '$taskCount 个任务'),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            calendar.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              _MetaChip(
                label: calendar.syncEnabled ? '同步开启' : '同步关闭',
                foregroundColor: calendar.syncEnabled
                    ? scheme.primary
                    : scheme.outline,
                backgroundColor: calendar.syncEnabled
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
              ),
              if (calendar.supportsTasks)
                const _MetaChip(label: '任务'),
              if (calendar.supportsEvents)
                const _MetaChip(label: '事件'),
              if (calendar.ctag != null)
                _MetaChip(label: 'CTag: ${calendar.ctag}'),
            ],
          ),
        ],
      ),
      value: calendar.syncEnabled,
      onChanged: (v) async {
        final repo = ref.read(calendarRepositoryProvider);
        await repo.setSyncEnabled(calendar.url, v);
      },
    );
  }

  Color _parseColor(String hex) {
    try {
      String value = hex.trim();
      if (value.isEmpty) return schemeDefaultColor;
      if (value.startsWith('#')) value = value.substring(1);
      if (value.length == 3) {
        value = value.split('').map((c) => '$c$c').join();
        value = 'ff$value';
      } else if (value.length == 6) {
        value = 'ff$value';
      } else if (value.length == 8) {
        value = value.substring(6, 8) + value.substring(0, 6);
      }
      return Color(int.parse(value, radix: 16));
    } catch (_) {
      return schemeDefaultColor;
    }
  }

  Color _foregroundColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  static const schemeDefaultColor = Colors.green;
}

/// 日历信息小标签。
class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    this.foregroundColor,
    this.backgroundColor,
  });

  final String label;
  final Color? foregroundColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor ?? scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: foregroundColor ?? scheme.outline,
        ),
      ),
    );
  }
}
