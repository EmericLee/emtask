/// CalDAV / WebDAV 响应解析后的中间模型。
///
/// 这些模型对应 multistatus XML 中的元素，作为 [CalDavClient] 与
/// 仓储层之间的数据载体，仓储层再转换为领域实体 [Task] / [Calendar]。
library;

/// 日历集合信息（PROPFIND 结果）。
class DavCalendarInfo {
  DavCalendarInfo({
    required this.href,
    required this.displayName,
    this.color,
    this.ctag,
    this.syncToken,
    this.supportsVTodo = false,
    this.supportsVEvent = false,
    this.owner,
  });

  /// 日历集合的相对 HREF
  final String href;

  final String displayName;

  final String? color;

  /// calendarserver CTag（变更令牌）
  final String? ctag;

  /// WebDAV sync-token
  final String? syncToken;

  final bool supportsVTodo;

  final bool supportsVEvent;

  final String? owner;
}

/// 任务资源信息（REPORT calendar-query 结果）。
class DavTaskResource {
  DavTaskResource({
    required this.href,
    this.etag,
    this.icalData,
  });

  /// 任务 .ics 资源的相对 HREF
  final String href;

  final String? etag;

  /// iCalendar 原文（calendar-data）
  final String? icalData;
}
