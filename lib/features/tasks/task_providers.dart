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

/// 任务列表（所有任务，不过滤日历，响应式）。
/// 各页面自行处理日历过滤逻辑，避免全局状态冲突。
final taskListProvider = StreamProvider<List<Task>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.watchAll(calendarUrl: null);
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
