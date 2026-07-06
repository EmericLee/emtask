import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_status.dart';

/// 当前选中的日历 URL（null 表示全部）。
final selectedCalendarProvider = StateProvider<String?>((ref) => null);

/// 完成情况过滤。
enum CompletionFilter { all, active, completed }

final completionFilterProvider =
    StateProvider<CompletionFilter>((ref) => CompletionFilter.all);

/// 截止时间过滤范围。
enum DueRange { anytime, today, thisWeek, thisMonth }

final dueRangeProvider = StateProvider<DueRange>((ref) => DueRange.anytime);

/// 排序方式。
enum SortMode { manual, alphabetical, dueDate, edited }

final sortModeProvider = StateProvider<SortMode>((ref) => SortMode.dueDate);

/// 标签过滤后孤儿任务（父任务不在结果集中）的显示模式。
enum OrphanDisplayMode {
  /// 树状：向上追溯父任务链，保持完整树状结构。
  tree,
  /// 前缀：孤儿任务提升为根，标题前显示父路径前缀。
  prefix,
}

/// 标签过滤后孤儿任务的显示模式（可在设置中切换）。
final orphanDisplayModeProvider = StateProvider<OrphanDisplayMode>(
  (ref) => OrphanDisplayMode.tree,
);

/// 是否隐藏已完成。
final hideCompletedProvider = StateProvider<bool>((ref) => false);

/// 日期字段是否显示时间（默认只显示日期，可在系统配置中开启）。
final showTimeInDateFieldProvider = StateProvider<bool>((ref) => false);

/// 任务列表（按选中日历过滤，响应式）。
final taskListProvider = StreamProvider<List<Task>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  final cal = ref.watch(selectedCalendarProvider);
  return repo.watchAll(calendarUrl: cal);
});

/// 任务详情（单个任务）。
final taskDetailProvider =
    FutureProvider.family<Task, int>((ref, localId) async {
  final repo = ref.watch(taskRepositoryProvider);
  final all = await repo.getAll();
  return all.firstWhere(
    (t) => t.localId == localId,
    orElse: () => throw StateError('任务不存在: $localId'),
  );
});

/// 创建任务的工具函数（非 provider，直接调用仓储）。
Future<Task> createTask(
  WidgetRef ref, {
  required String calendarUrl,
  required String summary,
  String description = '',
  DateTime? due,
  TaskPriority priority = TaskPriority.none,
  List<String> categories = const [],
}) {
  final repo = ref.read(taskRepositoryProvider);
  final task = Task.create(
    calendarUrl: calendarUrl,
    summary: summary,
    description: description,
    due: due,
    priority: priority,
    categories: categories,
  );
  return repo.create(task);
}

/// 批量保存手动排序结果（标记 dirty 以便同步到 Nextcloud）。
Future<void> saveSortOrders(
  WidgetRef ref,
  List<int> orderedLocalIds,
) {
  final repo = ref.read(taskRepositoryProvider);
  return repo.updateSortOrders(orderedLocalIds);
}
