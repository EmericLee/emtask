import '../entities/task.dart';

/// 任务仓储抽象。
///
/// 上层（UI / UseCase）只依赖此接口，具体实现由 data 层提供。
abstract class TaskRepository {
  /// 获取所有任务（按日历 URL 过滤，可选）
  Future<List<Task>> getAll({String? calendarUrl});

  /// 监听任务列表变化（响应式）
  Stream<List<Task>> watchAll({String? calendarUrl});

  /// 按 UID 获取单个任务
  Future<Task?> getByUid(String uid);

  /// 创建任务（本地标记 dirty，待同步上传）
  Future<Task> create(Task task);

  /// 更新任务（本地标记 dirty）
  Future<Task> update(Task task);

  /// 删除任务（本地标记 deleted，待同步删除）
  Future<void> delete(String uid);

  /// 获取所有待同步的任务（dirty 或 deleted）
  Future<List<Task>> getDirty();

  /// 获取所有待删除的任务
  Future<List<Task>> getDeleted();

  /// 标记任务已同步（清除 dirty / deleted，更新 etag/href）
  Future<void> markSynced(Task task, {String? etag, String? href});

  /// 用远端数据替换本地任务（同步下载用）
  Future<void> upsertFromRemote(Task task);

  /// 单任务排序更新（Nextcloud Tasks 算法）。
  ///
  /// 仅更新被移动任务的 sortOrder，返回 true 表示整数空间耗尽需兜底重排。
  /// 详见 AppDatabase.updateTaskSortOrder 的算法说明。
  Future<bool> updateTaskSortOrder({
    required int taskId,
    int? prevSort,
    int? nextSort,
  });

  /// 兜底重排：整组任务分配稀疏 sortOrder（手动拖拽耗尽整数空间时调用）。
  Future<void> updateSortOrders(List<int> orderedIds);
}
