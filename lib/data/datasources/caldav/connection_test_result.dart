/// CalDAV 连接测试结果（分步）。
class ConnectionTestResult {
  ConnectionTestResult();

  bool success = false;

  /// 步骤1：GET /status.php 测试基础连通性。
  String step1Ping = '';

  /// 步骤2：PROPFIND 列出日历集合。
  String step2Calendars = '';

  /// 步骤3：REPORT 查询首个日历的 VTODO。
  String step3VTodos = '';

  /// 第一个支持 VTODO 的日历 HREF（供后续步骤使用）。
  String? firstCalendarHref;

  /// 总耗时（毫秒）。
  int elapsedMs = 0;
}
