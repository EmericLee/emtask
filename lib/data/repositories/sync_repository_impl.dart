import '../../core/utils/app_logger.dart';
import '../../domain/repositories/sync_repository.dart';
import '../datasources/caldav/caldav_client.dart';
import '../datasources/caldav/caldav_exceptions.dart';
import '../datasources/caldav/caldav_models.dart';
import '../datasources/caldav/ical_serializer.dart';
import '../database/app_database.dart';
import 'calendar_repository_impl.dart';
import 'task_repository_impl.dart';

class SyncRepositoryImpl implements SyncRepository {
  SyncRepositoryImpl({
    required AppDatabase db,
    required CalDavClient client,
  })  : _db = db,
        _client = client,
        _tasks = TaskRepositoryImpl(db),
        _calendars = CalendarRepositoryImpl(db: db, client: client);

  final AppDatabase _db;
  final CalDavClient _client;
  final TaskRepositoryImpl _tasks;
  final CalendarRepositoryImpl _calendars;

  static const String _tag = 'Sync';

  @override
  Future<SyncResult> sync() async {
    AppLogger.instance.i(_tag, '==== 开始完整同步 ====');
    try {
      final pushResult = await push();
      // push 失败时停止同步，继续 pull 会用远端数据覆盖本地修改
      if (pushResult.error != null) {
        AppLogger.instance.e(_tag, 'push 失败，中止同步（不执行 pull）');
        return SyncResult(
          uploaded: pushResult.uploaded,
          deleted: pushResult.deleted,
          error: pushResult.error,
          finishedAt: DateTime.now().toUtc(),
        );
      }
      final pullResult = await pull();
      final r = SyncResult(
        uploaded: pushResult.uploaded,
        downloaded: pullResult.downloaded,
        updated: pullResult.updated,
        deleted: pullResult.deleted + pushResult.deleted,
        conflicts: 0,
        finishedAt: DateTime.now().toUtc(),
      );
      AppLogger.instance.i(_tag,
          '==== 完整同步结束 ↑${r.uploaded} ↓${r.downloaded} ~${r.updated} ✗${r.deleted} ====');
      return r;
    } catch (e, s) {
      AppLogger.instance.e(_tag, '完整同步异常', error: e, stackTrace: s);
      return SyncResult(
        error: e,
        finishedAt: DateTime.now().toUtc(),
      );
    }
  }

  @override
  Future<SyncResult> push() async {
    AppLogger.instance.i(_tag, '---- 开始 push ----');
    var uploaded = 0;
    var deleted = 0;
    try {
      // 上传 dirty 任务
      final dirty = await _tasks.getDirty();
      AppLogger.instance.i(_tag, '待上传(dirty)任务: ${dirty.length}');
      for (final task in dirty) {
        final cal = await _calendars.getByUrl(task.calendarUrl);
        if (cal == null) {
          AppLogger.instance.w(_tag, '跳过任务 uid=${task.uid}：找不到日历 ${task.calendarUrl}');
          continue;
        }

        final ical = IcalSerializer.serialize(task);
        // 优先使用已存储的 href（来自上次同步），没有时才按 uid 计算
        final taskHref = task.href ?? _taskHref(cal.url, task.uid);

        if (task.etag == null) {
          AppLogger.instance.d(_tag, '新建任务: $taskHref');
          try {
            final etag = await _client.createTask(
              taskHref: taskHref,
              icalData: ical,
            );
            await _tasks.markSynced(task, etag: etag, href: taskHref);
          } on CalDavException catch (e) {
            // 400 "uid already exists"：任务在远端已存在但 href 不同，
            // 查找正确的 href 并更新
            if (e.statusCode == 400 &&
                (e.responseBody ?? '').contains('already exists')) {
              AppLogger.instance.w(_tag,
                  'UID已存在(400)，查找正确href: ${task.uid}');
              final etag = await _findAndUpdateRemote(
                cal.url, task.uid, ical, taskHref,
              );
              await _tasks.markSynced(task, etag: etag.value, href: etag.href);
            } else {
              rethrow;
            }
          }
        } else {
          AppLogger.instance.d(_tag, '更新任务: $taskHref');
          try {
            final etag = await _client.updateTask(
              taskHref: taskHref,
              icalData: ical,
              etag: task.etag!,
            );
            await _tasks.markSynced(task, etag: etag, href: taskHref);
          } on CalDavException catch (e) {
            if (e.statusCode == 412) {
              // 412：远端资源在此 href 不存在，可能 href 已变更或资源被删除
              AppLogger.instance.w(_tag,
                  '远端资源不存在(412)，查找正确href: ${task.uid}');
              final etag = await _findAndUpdateRemote(
                cal.url, task.uid, ical, taskHref,
              );
              await _tasks.markSynced(task, etag: etag.value, href: etag.href);
            } else {
              rethrow;
            }
          }
        }
        uploaded++;
      }

      // 删除 deleted 任务
      final deletedTasks = await _tasks.getDeleted();
      AppLogger.instance.i(_tag, '待删除任务: ${deletedTasks.length}');
      for (final task in deletedTasks) {
        if (task.href != null && task.etag != null) {
          try {
            await _client.deleteTask(
              taskHref: task.href!,
              etag: task.etag,
            );
          } on CalDavException catch (e) {
            // 404 视为远端已删除，仍清理本地
            if (e.statusCode != 404) rethrow;
            AppLogger.instance.w(_tag, '远端已不存在: ${task.href}');
          }
        }
        await _db.hardDeleteTask(task.localId);
        deleted++;
      }

      AppLogger.instance.i(_tag, '---- push 结束 ↑$uploaded ✗$deleted ----');
      return SyncResult(
        uploaded: uploaded,
        deleted: deleted,
        finishedAt: DateTime.now().toUtc(),
      );
    } catch (e, s) {
      AppLogger.instance.e(_tag, 'push 异常', error: e, stackTrace: s);
      return SyncResult(
        uploaded: uploaded,
        deleted: deleted,
        error: e,
        finishedAt: DateTime.now().toUtc(),
      );
    }
  }

  @override
  Future<SyncResult> pull() async {
    AppLogger.instance.i(_tag, '---- 开始 pull ----');
    var downloaded = 0;
    var updated = 0;
    var deleted = 0;
    try {
      // 先从远端刷新日历列表写入本地数据库，否则本地无日历记录会导致后续跳过
      final remoteCalendars = await _calendars.refreshFromRemote();
      AppLogger.instance.i(_tag, '本地日历数: ${remoteCalendars.length}');

      var processedCalendars = 0;
      for (final cal in remoteCalendars) {
        if (!cal.syncEnabled) {
          AppLogger.instance.d(_tag, '跳过日历(未启用同步): ${cal.displayName}');
          continue;
        }
        if (!cal.supportsTasks) {
          AppLogger.instance.d(_tag, '跳过日历(不支持VTODO): ${cal.displayName}');
          continue;
        }
        processedCalendars++;

        // 检查 ctag 是否变化（getCalendarProperties 可能返回 null，不要用 !）
        DavCalendarInfo info;
        try {
          info = await _client.getCalendarProperties(cal.url) ??
              DavCalendarInfo(href: cal.url, displayName: cal.displayName);
        } catch (e) {
          AppLogger.instance.w(_tag, '获取日历属性失败，继续拉取: ${cal.url}  $e');
          info = DavCalendarInfo(href: cal.url, displayName: cal.displayName);
        }

        if (info.ctag != null && info.ctag == cal.ctag) {
          AppLogger.instance.i(_tag, '日历无变化(ctag相同): ${cal.displayName}');
          continue;
        }
        AppLogger.instance.i(_tag,
            '日历有变化: ${cal.displayName}  ctag ${cal.ctag ?? "-"} → ${info.ctag ?? "-"}');

        // 拉取所有 VTODO
        final remoteTasks = await _client.listVTodos(cal.url);
        AppLogger.instance.i(_tag, '日历 ${cal.displayName} 远端 VTODO: ${remoteTasks.length}');

        final remoteHrefs = <String>{};
        for (final r in remoteTasks) {
          remoteHrefs.add(r.href);
          if (r.icalData == null) continue;
          final task = IcalSerializer.parseVTodo(
            r.icalData!,
            calendarUrl: cal.url,
            href: r.href,
            etag: r.etag,
          );
          if (task == null) {
            AppLogger.instance.w(_tag, '解析失败: ${r.href}');
            continue;
          }
          await _db.upsertTaskFromRemote(task);
          downloaded++;
        }

        // 删除远端已不存在的本地任务
        final localTasks = await _db.getAllTasks(calendarUrl: cal.url);
        for (final local in localTasks) {
          if (local.href != null && !remoteHrefs.contains(local.href!)) {
            await _db.hardDeleteTask(local.localId);
            deleted++;
          }
        }

        // 更新 ctag
        await _calendars.update(cal.copyWith(
          ctag: info.ctag,
          syncToken: info.syncToken,
        ));
        updated++;
      }

      AppLogger.instance.i(_tag,
          '---- pull 结束 ↓$downloaded ~$updated ✗$deleted (处理$processedCalendars个日历) ----');
      return SyncResult(
        downloaded: downloaded,
        updated: updated,
        deleted: deleted,
        finishedAt: DateTime.now().toUtc(),
      );
    } catch (e, s) {
      AppLogger.instance.e(_tag, 'pull 异常', error: e, stackTrace: s);
      return SyncResult(
        downloaded: downloaded,
        updated: updated,
        deleted: deleted,
        error: e,
        finishedAt: DateTime.now().toUtc(),
      );
    }
  }

  /// 任务资源的 HREF：`<calendarUrl>/<uid>.ics`
  static String _taskHref(String calendarUrl, String uid) {
    final base = calendarUrl.endsWith('/')
        ? calendarUrl
        : '$calendarUrl/';
    return '$base$uid.ics';
  }

  /// 在远端日历中按 UID 查找任务，找到则更新，找不到则新建。
  ///
  /// 用于 412/400 错误恢复：远端资源 href 可能与本地不一致。
  /// 返回新的 etag 和实际使用的 href。
  Future<({String value, String href})> _findAndUpdateRemote(
    String calendarUrl,
    String uid,
    String icalData,
    String fallbackHref,
  ) async {
    // 列出日历下所有 VTODO，按 UID 匹配
    final remoteTasks = await _client.listVTodos(calendarUrl);
    DavTaskResource? match;
    for (final r in remoteTasks) {
      if (r.icalData == null) continue;
      // 在 iCalendar 数据中搜索 UID 行
      if (r.icalData!.contains('UID:$uid')) {
        match = r;
        break;
      }
    }

    if (match != null) {
      AppLogger.instance.i(_tag, '找到远端任务，更新: ${match.href}');
      final etag = await _client.updateTask(
        taskHref: match.href,
        icalData: icalData,
        etag: match.etag ?? '*',
      );
      return (value: etag, href: match.href);
    } else {
      // 远端确实不存在，新建
      AppLogger.instance.i(_tag, '远端未找到，新建: $fallbackHref');
      final etag = await _client.createTask(
        taskHref: fallbackHref,
        icalData: icalData,
      );
      return (value: etag, href: fallbackHref);
    }
  }
}
