import 'package:freezed_annotation/freezed_annotation.dart';

part 'calendar.freezed.dart';
part 'calendar.g.dart';

/// 日历实体，对应一个 CalDAV 日历集合。
///
/// Nextcloud 中每个任务列表即一个支持 VTODO 的日历。
@freezed
class Calendar with _$Calendar {
  const factory Calendar({
    /// 本地数据库主键
    required int localId,

    /// 远端日历集合 URL（绝对或相对，作为同步标识）
    required String url,

    /// 显示名称（CALDAV:displayname）
    required String displayName,

    /// 日历颜色（CALDAV:calendar-color）
    @Default('#2E7D32') String color,

    /// 是否支持 VTODO（任务）
    @Default(true) bool supportsTasks,

    /// 是否支持 VEVENT（事件）
    @Default(false) bool supportsEvents,

    /// 所属账户的用户名
    required String owner,

    /// 远端 CTag（同步令牌，用于增量判断）
    String? ctag,

    /// 远端 sync-token
    String? syncToken,

    /// 是否启用同步
    @Default(true) bool syncEnabled,
  }) = _Calendar;

  factory Calendar.fromJson(Map<String, dynamic> json) =>
      _$CalendarFromJson(json);
}
