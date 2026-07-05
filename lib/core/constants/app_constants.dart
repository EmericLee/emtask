/// 应用全局常量。
class AppConstants {
  const AppConstants._();

  /// 应用名称
  static const String appName = 'EM Task';

  /// 应用版本
  static const String appVersion = '0.1.0';

  /// 默认 CalDAV 端口
  static const int defaultCalDavPort = 443;

  /// Nextcloud Tasks 默认日历路径模板
  /// 使用时替换 {base} {user} {calendarId}
  static const String nextcloudCalendarsPathTemplate =
      '{base}/remote.php/dav/calendars/{user}/{calendarId}/';

  /// 用户代理
  static const String userAgent = 'EMTask/0.1.0 (CalDAV Client)';
}
