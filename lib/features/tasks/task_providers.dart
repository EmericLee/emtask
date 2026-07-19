import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_status.dart';

/// 排序方式。
enum SortMode { manual, alphabetical, dueDate, edited }

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

/// 新建任务后自动进入标题编辑状态（一次性信号）。
///
/// 设置为 true 后，详情页加载时将自动进入标题编辑模式；
/// 进入后应立即重置为 false，避免影响后续打开。
final autoEditTitleProvider = StateProvider<bool>((ref) => false);

/// 日期字段是否显示时间（默认只显示日期，可在系统配置中开启）。
final showTimeInDateFieldProvider = StateProvider<bool>((ref) => false);

/// 已完成任务的显示范围（默认不显示）。
enum CompletedRange {
  off, // 不显示已完成
  day1, // 1 天
  day3, // 3 天
  day7, // 7 天
  month1, // 1 月
  year1, // 1 年
  currentYear, // 当年
}

/// 已完成任务的显示范围（默认不显示）。
final completedRangeProvider =
    StateProvider<CompletedRange>((ref) => CompletedRange.off);

/// 任务视图模式：当前（关注）/ 全部 / 完成。
enum TaskViewMode {
  /// 重要：设置了优先级的、或截止日期在当前及之前的所有任务
  important,
  /// 当前：截止日期在配置天数内、或设了优先级、或进行中的任务
  current,
  /// 全部：所有任务（根据开关决定是否显示已完成）
  all,
  /// 完成：包含所有任务（含已完成）
  completed,
}

/// 任务页视图模式。
final taskViewModeProvider =
    StateProvider<TaskViewMode>((ref) => TaskViewMode.current);

/// "当前"视图的时间范围（天）：截止日期在未来多少天内的任务会被纳入。
final currentViewDaysProvider = StateProvider<int>((ref) => 7);

/// 基础过滤：排除已删除和已完成（根据完成范围）。
///
/// 供 [availableTagsForCalendarProvider] 与任务页面共享，确保标签候选列表
/// 与任务树可见任务保持一致。
List<Task> filterByCompletedRange(
  List<Task> tasks, {
  required CompletedRange completedRange,
}) {
  final now = DateTime.now().toUtc();
  DateTime? cutoff;
  switch (completedRange) {
    case CompletedRange.off:
      break;
    case CompletedRange.day1:
      cutoff = now.subtract(const Duration(days: 1));
    case CompletedRange.day3:
      cutoff = now.subtract(const Duration(days: 3));
    case CompletedRange.day7:
      cutoff = now.subtract(const Duration(days: 7));
    case CompletedRange.month1:
      cutoff = now.subtract(const Duration(days: 30));
    case CompletedRange.year1:
      cutoff = now.subtract(const Duration(days: 365));
    case CompletedRange.currentYear:
      cutoff = DateTime(now.year, 1, 1).toUtc();
  }
  return tasks.where((t) {
    if (t.deleted) return false;
    if (t.isCompleted) {
      if (completedRange == CompletedRange.off) return false;
      if (cutoff != null) {
        final completed = t.completed ?? t.lastModified ?? t.created;
        if (completed == null || completed.isBefore(cutoff)) return false;
      }
    }
    return true;
  }).toList();
}

/// 树状模式：向上追溯父任务链，把匹配任务及其所有祖先都包含进来。
List<Task> withAncestors(List<Task> matched, {required List<Task> allTasks}) {
  if (matched.isEmpty) return matched;
  final uidToTask = <String, Task>{
    for (final t in allTasks) t.uid: t,
  };
  final result = <Task>[];
  final added = <String>{};
  void addWithAncestors(Task t) {
    if (added.contains(t.uid)) return;
    added.add(t.uid);
    final p = t.parentUid;
    if (p != null && p.isNotEmpty && uidToTask.containsKey(p)) {
      addWithAncestors(uidToTask[p]!);
    }
    result.add(t);
  }

  for (final t in matched) {
    addWithAncestors(t);
  }
  return result;
}

/// 按视图模式过滤任务。
///
/// - [TaskViewMode.important]：设了优先级或截止日期在当前及之前的任务
/// - [TaskViewMode.current]：截止 [currentViewDays] 天内、或设了优先级、或进行中的任务
/// - [TaskViewMode.all]：所有任务（根据开关决定是否显示已完成）
/// - [TaskViewMode.completed]：包含所有任务（含已完成，仅排除已删除）
List<Task> filterByViewMode(
  List<Task> tasks, {
  required CompletedRange completedRange,
  required TaskViewMode viewMode,
  required int currentViewDays,
}) {
  switch (viewMode) {
    case TaskViewMode.important:
      final base = filterByCompletedRange(tasks, completedRange: completedRange);
      final now = DateTime.now().toUtc();
      final matched = base.where((t) {
        if (t.priority != TaskPriority.none) return true;
        if (t.due != null && !t.due!.isAfter(now)) return true;
        return false;
      }).toList();
      return withAncestors(matched, allTasks: base);
    case TaskViewMode.current:
      final base = filterByCompletedRange(tasks, completedRange: completedRange);
      final now = DateTime.now().toUtc();
      final dueCutoff = now.add(Duration(days: currentViewDays));
      final matched = base.where((t) {
        if (t.due != null && t.due!.isBefore(dueCutoff)) return true;
        if (t.priority != TaskPriority.none) return true;
        if (t.status == TaskStatus.inProcess) return true;
        return false;
      }).toList();
      return withAncestors(matched, allTasks: base);
    case TaskViewMode.all:
      return filterByCompletedRange(tasks, completedRange: completedRange);
    case TaskViewMode.completed:
      return tasks.where((t) => !t.deleted).toList();
  }
}

/// 任务列表（所有任务，不过滤日历，响应式）。
/// 各页面自行处理日历过滤逻辑，避免全局状态冲突。
final taskListProvider = StreamProvider<List<Task>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.watchAll(calendarUrl: null);
});

/// 指定清单下可见任务的标签候选集合（响应式，供标签编辑器检索）。
///
/// 过滤逻辑与任务树完全一致：应用视图模式过滤（重要/当前/全部/完成）
/// + 完成范围过滤 + 清单过滤。只有任务树中可见的任务才参与标签汇总。
///
/// 传入 null 时汇总所有清单的可见任务标签（兜底场景）。
final availableTagsForCalendarProvider =
    Provider.family<List<String>, String?>((ref, calendarUrl) {
  final tasks = ref.watch(taskListProvider).valueOrNull ?? const <Task>[];
  final completedRange = ref.watch(completedRangeProvider);
  final viewMode = ref.watch(taskViewModeProvider);
  final currentViewDays = ref.watch(currentViewDaysProvider);
  // 应用与任务树相同的过滤逻辑
  var visibleTasks = filterByViewMode(
    tasks,
    completedRange: completedRange,
    viewMode: viewMode,
    currentViewDays: currentViewDays,
  );
  if (calendarUrl != null) {
    visibleTasks = visibleTasks
        .where((t) => t.calendarUrl == calendarUrl)
        .toList();
  }
  final tags = <String>{};
  for (final t in visibleTasks) {
    tags.addAll(t.categories);
  }
  return tags.toList()..sort();
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

/// 单任务排序更新（Nextcloud Tasks 排序算法）。
///
/// 仅更新被移动任务的 sortOrder，返回 true 表示整数空间耗尽，
/// 调用方应接着调用 [saveSortOrders] 对该组做稀疏重排。
///
/// 参数：
///   [taskId] 被移动任务 localId
///   [prevSort] 新位置前一个兄弟任务的 sortOrder（拖到开头时为 null）
///   [nextSort] 新位置后一个兄弟任务的 sortOrder（拖到末尾时为 null）
Future<bool> saveTaskSortOrder(
  WidgetRef ref, {
  required int taskId,
  int? prevSort,
  int? nextSort,
}) {
  final repo = ref.read(taskRepositoryProvider);
  return repo.updateTaskSortOrder(
    taskId: taskId,
    prevSort: prevSort,
    nextSort: nextSort,
  );
}

/// 兜底重排：将整组任务分配稀疏 sortOrder（间距 1000）。
///
/// 在 [saveTaskSortOrder] 返回 true（整数空间耗尽）时调用，
/// 或在需要强制重排某组的场景使用。标记 dirty 以便同步到 Nextcloud。
Future<void> saveSortOrders(
  WidgetRef ref,
  List<int> orderedLocalIds,
) {
  final repo = ref.read(taskRepositoryProvider);
  return repo.updateSortOrders(orderedLocalIds);
}
