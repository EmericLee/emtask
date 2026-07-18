import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../database/app_database.dart';

class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<List<Task>> getAll({String? calendarUrl}) =>
      _db.getAllTasks(calendarUrl: calendarUrl);

  @override
  Stream<List<Task>> watchAll({String? calendarUrl}) =>
      _db.watchTasks(calendarUrl: calendarUrl);

  @override
  Future<Task?> getByUid(String uid) async {
    // 注意：需要 calendarUrl 才能精确定位，这里取任意一个匹配项
    final all = await _db.getAllTasks();
    for (final t in all) {
      if (t.uid == uid) return t;
    }
    return null;
  }

  @override
  Future<Task> create(Task task) => _db.createTask(task);

  @override
  Future<Task> update(Task task) => _db.updateTask(task);

  @override
  Future<void> delete(String uid) async {
    final t = await getByUid(uid);
    if (t != null) {
      await _db.softDeleteTask(t.localId);
    }
  }

  @override
  Future<List<Task>> getDirty() => _db.getDirtyTasks();

  @override
  Future<List<Task>> getDeleted() => _db.getDeletedTasks();

  @override
  Future<void> markSynced(Task task, {String? etag, String? href}) =>
      _db.markTaskSynced(task.localId, etag: etag, href: href);

  @override
  Future<void> upsertFromRemote(Task task) => _db.upsertTaskFromRemote(task);

  @override
  Future<bool> updateTaskSortOrder({
    required int taskId,
    int? prevSort,
    int? nextSort,
  }) =>
      _db.updateTaskSortOrder(
        taskId: taskId,
        prevSort: prevSort,
        nextSort: nextSort,
      );

  @override
  Future<void> updateSortOrders(List<int> orderedIds) =>
      _db.updateSortOrders(orderedIds);
}
