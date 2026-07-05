import 'package:drift/drift.dart';

/// 日历表（CalDAV 日历集合的本地缓存）。
@DataClassName('CalendarRow')
class Calendars extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 远端日历集合 URL（同步主键）
  TextColumn get url => text().unique()();

  TextColumn get displayName => text().withDefault(const Constant(''))();

  TextColumn get color => text().withDefault(const Constant('#2E7D32'))();

  BoolColumn get supportsVTodo => boolean().withDefault(const Constant(true))();

  BoolColumn get supportsVEvent => boolean().withDefault(const Constant(false))();

  TextColumn get owner => text().withDefault(const Constant(''))();

  /// calendarserver CTag
  TextColumn get ctag => text().nullable()();

  /// WebDAV sync-token
  TextColumn get syncToken => text().nullable()();

  BoolColumn get syncEnabled => boolean().withDefault(const Constant(true))();
}
