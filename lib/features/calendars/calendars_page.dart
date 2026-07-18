import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/entities/calendar.dart';
import '../sync/sync_providers.dart';
import '../tasks/task_page.dart';
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
          // 日历列表保持远端返回的原始顺序，不强制重排
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
    final defaultCalendarUrl = ref.watch(defaultCalendarUrlProvider);
    final isDefault = defaultCalendarUrl == calendar.url;

    return ListTile(
      leading: Container(
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
      title: Text(
        calendar.displayName,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (taskCount != null)
              _MetaChip(label: '$taskCount 任务'),
            if (calendar.supportsTasks)
              const _MetaChip(label: 'VTODO'),
            if (calendar.supportsEvents)
              const _MetaChip(label: 'VEVENT'),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 设为默认按钮：仅支持任务且已启用同步的清单可设为默认
          if (calendar.supportsTasks && calendar.syncEnabled)
            TextButton(
              onPressed: isDefault
                  ? null
                  : () {
                      // 通过 Notifier.set 持久化保存，确保应用重启后仍生效
                      ref
                          .read(defaultCalendarUrlProvider.notifier)
                          .set(calendar.url);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('已将「${calendar.displayName}」设为默认日历'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: isDefault ? scheme.outline : scheme.primary,
              ),
              child: Text(
                isDefault ? '默认' : '设为默认',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          Switch(
            value: calendar.syncEnabled,
            onChanged: (v) async {
              final repo = ref.read(calendarRepositoryProvider);
              await repo.setSyncEnabled(calendar.url, v);
              // 关闭同步时，若该清单是当前默认日历，自动清除默认设置，
              // 避免新建任务落到未同步的清单上
              if (!v && isDefault) {
                ref.read(defaultCalendarUrlProvider.notifier).set(null);
              }
            },
          ),
        ],
      ),
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
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: scheme.outline,
        ),
      ),
    );
  }
}
