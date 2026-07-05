import 'package:drift/drift.dart';

/// 任务表（VTODO 的本地缓存）。
///
/// [uid] + [calendarUrl] 是业务主键；[id] 仅是本地自增主键。
/// [dirty] / [deleted] 用于离线变更追踪与同步。
@DataClassName('TaskRow')
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get calendarUrl => text()();

  /// iCalendar UID（全局唯一）
  TextColumn get uid => text()();

  TextColumn get summary => text().withDefault(const Constant(''))();

  TextColumn get description => text().withDefault(const Constant(''))();

  DateTimeColumn get start => dateTime().nullable()();

  DateTimeColumn get due => dateTime().nullable()();

  DateTimeColumn get completed => dateTime().nullable()();

  /// 状态：NEEDS-ACTION / IN-PROCESS / COMPLETED / CANCELLED
  TextColumn get status =>
      text().withDefault(const Constant('NEEDS-ACTION'))();

  /// 优先级：0/1/5/9
  IntColumn get priority => integer().withDefault(const Constant(0))();

  IntColumn get percent => integer().withDefault(const Constant(0))();

  /// 分类标签，以 JSON 数组字符串存储
  TextColumn get categories => text().withDefault(const Constant('[]'))();

  TextColumn get parentUid => text().nullable()();

  /// 远端 .ics 资源 HREF
  TextColumn get href => text().nullable()();

  /// 远端 ETag
  TextColumn get etag => text().nullable()();

  DateTimeColumn get created => dateTime().nullable()();

  DateTimeColumn get lastModified => dateTime().nullable()();

  /// 本地最后修改时间
  DateTimeColumn get localModifiedAt => dateTime().nullable()();

  /// 手动排序值（对应 iCalendar X-APPLE-SORT-ORDER，数字越小越靠前）
  IntColumn get sortOrder => integer().nullable()();

  /// 是否待同步上传
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  /// 是否已被本地删除（待同步删除）
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {uid, calendarUrl},
      ];
}
