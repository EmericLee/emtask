import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/entities/calendar.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_status.dart';
import 'tables/calendars_table.dart';
import 'tables/tasks_table.dart';

part 'app_database.g.dart';

/// 应用本地数据库（基于 Drift / SQLite）。
///
/// 缓存日历与任务，承载离线变更（dirty / deleted）。
@DriftDatabase(tables: [Calendars, Tasks])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2: 新增 sort_order 列
            await m.addColumn(tasks, tasks.sortOrder);
          }
        },
      );

  // ---------------- Calendars ----------------

  /// 监听日历列表
  Stream<List<Calendar>> watchCalendars() {
    return select(calendars).watch().map(
          (rows) => rows.map(_toCalendarEntity).toList(),
        );
  }

  Future<List<Calendar>> getAllCalendars() =>
      select(calendars).map(_toCalendarEntity).get();

  Future<Calendar?> getCalendarByUrl(String url) async {
    final q = select(calendars)
      ..where((t) => t.url.equals(url));
    final row = await q.getSingleOrNull();
    return row == null ? null : _toCalendarEntity(row);
  }

  Future<void> upsertCalendar(Calendar c) async {
    final existing = await getCalendarByUrl(c.url);
    if (existing == null) {
      await into(calendars).insert(
        CalendarsCompanion.insert(
          url: c.url,
          displayName: Value(c.displayName),
          color: Value(c.color),
          supportsVTodo: Value(c.supportsTasks),
          supportsVEvent: Value(c.supportsEvents),
          owner: Value(c.owner),
          ctag: Value(c.ctag),
          syncToken: Value(c.syncToken),
          syncEnabled: Value(c.syncEnabled),
        ),
      );
    } else {
      await (update(calendars)..where((t) => t.id.equals(existing.localId)))
          .write(
        CalendarsCompanion(
          url: Value(c.url),
          displayName: Value(c.displayName),
          color: Value(c.color),
          supportsVTodo: Value(c.supportsTasks),
          supportsVEvent: Value(c.supportsEvents),
          owner: Value(c.owner),
          ctag: Value(c.ctag),
          syncToken: Value(c.syncToken),
          syncEnabled: Value(c.syncEnabled),
        ),
      );
    }
  }

  Future<void> setCalendarSyncEnabled(String url, bool enabled) async {
    await (update(calendars)..where((t) => t.url.equals(url)))
        .write(CalendarsCompanion(syncEnabled: Value(enabled)));
  }

  // ---------------- Tasks ----------------

  Stream<List<Task>> watchTasks({String? calendarUrl}) {
    final q = select(tasks)
      ..where((t) => t.deleted.equals(false));
    if (calendarUrl != null) {
      q.where((t) => t.calendarUrl.equals(calendarUrl));
    }
    return q.watch().map((rows) => rows.map(_toTaskEntity).toList());
  }

  Future<List<Task>> getAllTasks({String? calendarUrl}) async {
    final q = select(tasks)
      ..where((t) => t.deleted.equals(false));
    if (calendarUrl != null) {
      q.where((t) => t.calendarUrl.equals(calendarUrl));
    }
    return q.map(_toTaskEntity).get();
  }

  Future<Task?> getTaskByUid(String uid, String calendarUrl) async {
    final q = select(tasks)
      ..where((t) => t.uid.equals(uid) & t.calendarUrl.equals(calendarUrl));
    final row = await q.getSingleOrNull();
    return row == null ? null : _toTaskEntity(row);
  }

  Future<List<Task>> getDirtyTasks() {
    final q = select(tasks)
      ..where((t) => t.dirty.equals(true) & t.deleted.equals(false));
    return q.map(_toTaskEntity).get();
  }

  Future<List<Task>> getDeletedTasks() {
    final q = select(tasks)
      ..where((t) => t.deleted.equals(true));
    return q.map(_toTaskEntity).get();
  }

  Future<Task> createTask(Task task) async {
    final companion = _toCompanion(task, isNew: true);
    final id = await into(tasks).insert(companion);
    return task.copyWith(localId: id);
  }

  Future<Task> updateTask(Task task) async {
    final companion = _toCompanion(task, isNew: false).copyWith(
      dirty: const Value(true),
      localModifiedAt: Value(DateTime.now().toUtc()),
    );
    await (update(tasks)..where((t) => t.id.equals(task.localId)))
        .write(companion);
    return task.copyWith(
      dirty: true,
      localModifiedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> softDeleteTask(int localId) async {
    await (update(tasks)..where((t) => t.id.equals(localId))).write(
      TasksCompanion(
        deleted: const Value(true),
        dirty: const Value(true),
        localModifiedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> markTaskSynced(
    int localId, {
    String? etag,
    String? href,
  }) async {
    await (update(tasks)..where((t) => t.id.equals(localId))).write(
      TasksCompanion(
        dirty: const Value(false),
        deleted: const Value(false),
        etag: etag != null ? Value(etag) : const Value.absent(),
        href: href != null ? Value(href) : const Value.absent(),
      ),
    );
  }

  Future<void> hardDeleteTask(int localId) async {
    await (delete(tasks)..where((t) => t.id.equals(localId))).go();
  }

  Future<void> upsertTaskFromRemote(Task task) async {
    final existing = await getTaskByUid(task.uid, task.calendarUrl);
    if (existing == null) {
      final companion = _toCompanion(task, isNew: true).copyWith(
        dirty: const Value(false),
        deleted: const Value(false),
      );
      await into(tasks).insert(companion);
    } else {
      // 远端优先：用远端数据覆盖本地（若本地正在 dirty，则需冲突处理，
      // 此处简化为远端优先；后续 SyncRepository 可加冲突策略）。
      await (update(tasks)..where((t) => t.id.equals(existing.localId)))
          .write(
        _toCompanion(task, isNew: false).copyWith(
          id: const Value.absent(), // 不更新主键
          dirty: const Value(false),
          deleted: const Value(false),
        ),
      );
    }
  }

  Future<void> hardDeleteTaskByUid(String uid, String calendarUrl) async {
    await (delete(tasks)
          ..where(
              (t) => t.uid.equals(uid) & t.calendarUrl.equals(calendarUrl)))
        .go();
  }

  /// 批量更新任务排序值（手动拖拽排序后调用）。
  /// [orderedIds] 为按新顺序排列的任务 localId 列表。
  Future<void> updateSortOrders(List<int> orderedIds) async {
    final now = DateTime.now().toUtc();
    await batch((b) {
      for (var i = 0; i < orderedIds.length; i++) {
        b.update(
          tasks,
          TasksCompanion(
            sortOrder: Value(i),
            dirty: const Value(true),
            localModifiedAt: Value(now),
          ),
          where: (t) => t.id.equals(orderedIds[i]),
        );
      }
    });
  }

  // ---------------- 转换 ----------------

  static Calendar _toCalendarEntity(CalendarRow r) => Calendar(
        localId: r.id,
        url: r.url,
        displayName: r.displayName,
        color: r.color,
        supportsTasks: r.supportsVTodo,
        supportsEvents: r.supportsVEvent,
        owner: r.owner,
        ctag: r.ctag,
        syncToken: r.syncToken,
        syncEnabled: r.syncEnabled,
      );

  static Task _toTaskEntity(TaskRow r) {
    final cats = (jsonDecode(r.categories) as List<dynamic>)
        .cast<String>();
    return Task(
      localId: r.id,
      calendarUrl: r.calendarUrl,
      uid: r.uid,
      summary: r.summary,
      description: r.description,
      start: r.start,
      due: r.due,
      completed: r.completed,
      status: TaskStatus.fromIcal(r.status),
      priority: TaskPriority.fromIcal(r.priority),
      percent: r.percent,
      categories: cats,
      parentUid: r.parentUid,
      href: r.href,
      etag: r.etag,
      created: r.created,
      lastModified: r.lastModified,
      localModifiedAt: r.localModifiedAt,
      sortOrder: r.sortOrder,
      dirty: r.dirty,
      deleted: r.deleted,
    );
  }

  static TasksCompanion _toCompanion(Task t, {required bool isNew}) {
    return TasksCompanion(
      id: isNew ? const Value.absent() : Value(t.localId),
      calendarUrl: Value(t.calendarUrl),
      uid: Value(t.uid),
      summary: Value(t.summary),
      description: Value(t.description),
      start: Value(t.start),
      due: Value(t.due),
      completed: Value(t.completed),
      status: Value(t.status.icalValue),
      priority: Value(t.priority.icalValue),
      percent: Value(t.percent),
      categories: Value(jsonEncode(t.categories)),
      parentUid: Value(t.parentUid),
      href: Value(t.href),
      etag: Value(t.etag),
      created: Value(t.created),
      lastModified: Value(t.lastModified),
      localModifiedAt: Value(t.localModifiedAt),
      sortOrder: Value(t.sortOrder),
      dirty: Value(t.dirty),
      deleted: Value(t.deleted),
    );
  }
}

/// 打开 / 创建数据库文件。
QueryExecutor _open() {
  return driftDatabase(name: 'em_task');
}
