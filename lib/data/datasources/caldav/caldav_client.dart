import 'dart:io';

import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:xml/xml.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/app_logger.dart';
import 'caldav_account.dart';
import 'caldav_constants.dart';
import 'caldav_exceptions.dart';
import 'caldav_models.dart';
import 'connection_test_result.dart';

/// CalDAV 客户端，负责与 Nextcloud Tasks 服务端通信。
///
/// 实现以下 WebDAV / CalDAV 方法：
/// - [PROPFIND](https://datatracker.ietf.org/doc/html/rfc4918) 列出日历 / 获取属性
/// - [REPORT](https://datatracker.ietf.org/doc/html/rfc4791) calendar-query 查询 VTODO
/// - GET / PUT / DELETE 单个任务资源
///
/// 示例：
/// ```dart
/// final client = CalDavClient(account: account);
/// final calendars = await client.listCalendars();
/// ```
class CalDavClient {
  CalDavClient({
    required this.account,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? _buildHttpClient(account);

  final CalDavAccount account;

  final http.Client _httpClient;

  /// 日志 tag。
  static const String tag = 'CalDav';

  /// 构造 HTTP 客户端：根据是否信任自签名证书创建 IOClient。
  static http.Client _buildHttpClient(CalDavAccount acc) {
    if (!acc.trustSelfSignedCert) {
      return http.Client();
    }
    final ioClient = HttpClient()
      ..badCertificateCallback = (_, _, _) => true;
    AppLogger.instance.w(tag, '已启用信任自签名证书模式，跳过 TLS 校验');
    return IOClient(ioClient);
  }

  /// 释放底层 HTTP 连接。
  void close() => _httpClient.close();

  // ---------------- 日历操作 ----------------

  /// 列出当前用户的所有日历集合（仅返回支持 VTODO 的）。
  Future<List<DavCalendarInfo>> listCalendars() async {
    final body = _propfindCalendarHomeBody();
    final resp = await _send(
      method: CalDavMethod.propfind,
      path: account.nextcloudCalendarsHome,
      headers: {'Depth': '1'},
      body: body,
      contentType: 'application/xml; charset=utf-8',
    );
    return _parseCalendarMultistatus(resp.body)
        .where((c) => c.supportsVTodo)
        .toList();
  }

  /// 获取单个日历的属性（ctag / sync-token / displayname）。
  Future<DavCalendarInfo?> getCalendarProperties(String calendarHref) async {
    final body = _propfindCalendarPropsBody();
    final resp = await _send(
      method: CalDavMethod.propfind,
      path: calendarHref,
      headers: {'Depth': '0'},
      body: body,
      contentType: 'application/xml; charset=utf-8',
    );
    final list = _parseCalendarMultistatus(resp.body);
    return list.isEmpty ? null : list.first;
  }

  // ---------------- 任务操作 ----------------

  /// 查询日历下所有 VTODO（带 calendar-data）。
  ///
  /// 一次 REPORT 请求即可拿到所有任务的 HREF / ETag / iCalendar 内容。
  Future<List<DavTaskResource>> listVTodos(String calendarHref) async {
    final body = _calendarQueryVTodoBody();
    final resp = await _send(
      method: CalDavMethod.report,
      path: calendarHref,
      headers: {'Depth': '1'},
      body: body,
      contentType: 'application/xml; charset=utf-8',
    );
    return _parseTaskMultistatus(resp.body);
  }

  /// 仅查询 VTODO 的 HREF 与 ETag（不含内容，用于增量同步比较）。
  Future<List<DavTaskResource>> listVTodoEtags(String calendarHref) async {
    final body = _calendarQueryEtagBody();
    final resp = await _send(
      method: CalDavMethod.report,
      path: calendarHref,
      headers: {'Depth': '1'},
      body: body,
      contentType: 'application/xml; charset=utf-8',
    );
    return _parseTaskMultistatus(resp.body);
  }

  /// 下载单个任务 .ics。
  Future<DavTaskResource> getTask(String taskHref) async {
    final resp = await _send(
      method: 'GET',
      path: taskHref,
      headers: {'Accept': 'text/calendar'},
    );
    return DavTaskResource(
      href: taskHref,
      etag: resp.headers['etag'],
      icalData: resp.body,
    );
  }

  /// 创建任务（PUT 到新 HREF）。
  ///
  /// [taskHref] 通常是 `<calendarHref>/<uid>.ics`。
  /// [icalData] 为 [IcalSerializer.serialize] 输出。
  /// 返回服务端返回的 ETag。
  Future<String> createTask({
    required String taskHref,
    required String icalData,
  }) async {
    final resp = await _send(
      method: 'PUT',
      path: taskHref,
      headers: {'Content-Type': 'text/calendar; charset=utf-8'},
      body: icalData,
    );
    final etag = resp.headers['etag'];
    if (etag == null) {
      throw CalDavException('创建任务后未返回 ETag', statusCode: resp.statusCode);
    }
    return etag;
  }

  /// 更新任务（带 If-Match 乐观并发控制）。
  Future<String> updateTask({
    required String taskHref,
    required String icalData,
    required String etag,
  }) async {
    final resp = await _send(
      method: 'PUT',
      path: taskHref,
      headers: {
        'Content-Type': 'text/calendar; charset=utf-8',
        'If-Match': etag,
      },
      body: icalData,
    );
    final newEtag = resp.headers['etag'];
    if (newEtag == null) {
      throw CalDavException('更新任务后未返回 ETag', statusCode: resp.statusCode);
    }
    return newEtag;
  }

  /// 删除任务。
  Future<void> deleteTask({required String taskHref, String? etag}) async {
    final headers = <String, String>{};
    if (etag != null) headers['If-Match'] = etag;
    await _send(
      method: 'DELETE',
      path: taskHref,
      headers: headers,
    );
  }

  // ---------------- 连接测试 ----------------

  /// 连接测试：依次执行 ping、列出日历、查询第一个日历的 VTODO 数量。
  ///
  /// 返回分步结果，便于在诊断页显示。所有异常都被捕获并写入结果。
  Future<ConnectionTestResult> testConnection() async {
    AppLogger.instance.i(tag, '==== 开始连接测试 ====');
    final r = ConnectionTestResult();

    // 1. 基础连通（status.php 在 Nextcloud 根目录，非 /remote.php/dav 下）
    try {
      final statusUrl = '${account.sanitizedBaseUrl}/status.php';
      AppLogger.instance.d(tag, '步骤1: GET $statusUrl');
      final resp = await _send(
        method: 'GET',
        path: statusUrl,
        headers: {'Accept': 'application/json'},
      );
      r.step1Ping = 'OK (${resp.statusCode})\n${resp.body.substring(0, resp.body.length > 300 ? 300 : resp.body.length)}';
      AppLogger.instance.i(tag, '步骤1通过: HTTP ${resp.statusCode}');
    } catch (e, s) {
      r.step1Ping = 'FAIL: $e';
      AppLogger.instance.e(tag, '步骤1失败: ping status.php', error: e, stackTrace: s);
      r.success = false;
      return r;
    }

    // 2. 列出日历
    try {
      AppLogger.instance.d(tag, '步骤2: PROPFIND ${account.nextcloudCalendarsHome}');
      final list = await listCalendars();
      r.step2Calendars = 'OK: 共 ${list.length} 个日历（含 VTODO 支持）';
      for (final c in list) {
        r.step2Calendars += '\n  - ${c.displayName}  ${c.href}  ctag=${c.ctag ?? "-"}';
      }
      AppLogger.instance.i(tag, '步骤2通过: ${list.length} 个日历');
      if (list.isEmpty) {
        r.step3VTodos = '跳过（无支持 VTODO 的日历）';
        r.success = true;
        return r;
      }
      r.firstCalendarHref = list.first.href;
    } catch (e, s) {
      r.step2Calendars = 'FAIL: $e';
      AppLogger.instance.e(tag, '步骤2失败: 列日历', error: e, stackTrace: s);
      r.success = false;
      return r;
    }

    // 3. 查询 VTODO
    try {
      AppLogger.instance.d(tag, '步骤3: REPORT ${r.firstCalendarHref}');
      final todos = await listVTodos(r.firstCalendarHref!);
      r.step3VTodos = 'OK: 共 ${todos.length} 个 VTODO';
      AppLogger.instance.i(tag, '步骤3通过: ${todos.length} 个 VTODO');
      r.success = true;
    } catch (e, s) {
      r.step3VTodos = 'FAIL: $e';
      AppLogger.instance.e(tag, '步骤3失败: 查询 VTODO', error: e, stackTrace: s);
      r.success = false;
    }

    AppLogger.instance.i(tag, '==== 连接测试结束 success=${r.success} ====');
    return r;
  }

  // ---------------- HTTP 底层 ----------------

  Future<http.Response> _send({
    required String method,
    required String path,
    Map<String, String> headers = const {},
    String? body,
    String? contentType,
  }) async {
    final uri = _resolveUri(path);
    AppLogger.instance.d(tag, '→ $method $uri');
    final req = http.Request(method, uri);

    req.headers.addAll({
      'Authorization': account.basicAuthHeader,
      'User-Agent': AppConstants.userAgent,
      'Content-Type': ?contentType,
    });
    req.headers.addAll(headers);

    if (body != null) {
      req.body = body;
    }

    final streamed = await _httpClient.send(req);
    final resp = await http.Response.fromStream(streamed);

    AppLogger.instance.d(
      tag,
      '← ${resp.statusCode} ${resp.reasonPhrase ?? ""}  ${resp.body.length}B  ($method $uri)',
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final snippet = resp.body.length > 500
          ? '${resp.body.substring(0, 500)}...'
          : resp.body;
      AppLogger.instance.e(
        tag,
        'HTTP ${resp.statusCode} $method $uri\n$snippet',
      );
      throw CalDavException(
        '请求失败：$method $uri → ${resp.statusCode}',
        statusCode: resp.statusCode,
        responseBody: resp.body,
      );
    }
    return resp;
  }

  Uri _resolveUri(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }
    // 相对路径，拼接 sanitizedBaseUrl（已去掉 /remote.php/dav 等后缀）
    final base = account.sanitizedBaseUrl;
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$p');
  }

  // ---------------- XML 请求体 ----------------

  static String _propfindCalendarHomeBody() {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<d:propfind xmlns:d="DAV:" xmlns:cs="http://calendarserver.org/ns/" xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:nc="http://nextcloud.org/ns/" xmlns:oc="http://owncloud.org/ns">
  <d:prop>
    <d:resourcetype/>
    <d:displayname/>
    <cs:getctag/>
    <d:sync-token/>
    <nc:color/>
    <oc:calendar-enabled/>
    <c:supported-calendar-component-set/>
    <d:owner/>
  </d:prop>
</d:propfind>''';
  }

  static String _propfindCalendarPropsBody() {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<d:propfind xmlns:d="DAV:" xmlns:cs="http://calendarserver.org/ns/" xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:nc="http://nextcloud.org/ns/">
  <d:prop>
    <d:displayname/>
    <cs:getctag/>
    <d:sync-token/>
    <nc:color/>
    <c:supported-calendar-component-set/>
  </d:prop>
</d:propfind>''';
  }

  static String _calendarQueryVTodoBody() {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop>
    <d:getetag/>
    <c:calendar-data/>
  </d:prop>
  <c:filter>
    <c:comp-filter name="VCALENDAR">
      <c:comp-filter name="VTODO"/>
    </c:comp-filter>
  </c:filter>
</c:calendar-query>''';
  }

  static String _calendarQueryEtagBody() {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop>
    <d:getetag/>
  </d:prop>
  <c:filter>
    <c:comp-filter name="VCALENDAR">
      <c:comp-filter name="VTODO"/>
    </c:comp-filter>
  </c:filter>
</c:calendar-query>''';
  }

  // ---------------- XML 响应解析 ----------------

  static List<DavCalendarInfo> _parseCalendarMultistatus(String xmlStr) {
    final doc = XmlDocument.parse(xmlStr);
    final multistatus = doc.rootElement;
    final results = <DavCalendarInfo>[];

    for (final response in multistatus.findElements('response', namespace: '*')) {
      final href = _childText(response, 'href');
      if (href == null) continue;

      final propstat = response.findElements('propstat', namespace: '*').firstOrNull;
      if (propstat == null) continue;

      final prop = propstat.findElements('prop', namespace: '*').firstOrNull;
      if (prop == null) continue;

      final resourceType = prop.findElements('resourcetype', namespace: '*').firstOrNull;
      // 仅处理日历集合（含 <collection/> 与 <calendar/>）
      if (resourceType == null) continue;
      final isCalendar = resourceType
          .findElements('calendar', namespace: '*')
          .isNotEmpty;
      if (!isCalendar) continue;

      final displayName = _childText(prop, 'displayname') ?? '';
      final ctag = _childText(prop, 'getctag');
      final syncToken = _childText(prop, 'sync-token');
      final color = _childText(prop, 'color');
      final owner = _childText(prop, 'owner');

      // supported-calendar-component-set 内的 comp 元素 name 属性
      final compSet = prop
          .findElements('supported-calendar-component-set', namespace: '*')
          .firstOrNull;
      var supportsVTodo = false;
      var supportsVEvent = false;
      if (compSet != null) {
        for (final comp in compSet.findElements('comp', namespace: '*')) {
          final name = comp.getAttribute('name')?.toUpperCase();
          if (name == 'VTODO') supportsVTodo = true;
          if (name == 'VEVENT') supportsVEvent = true;
        }
      }

      results.add(DavCalendarInfo(
        href: href,
        displayName: displayName,
        color: color,
        ctag: ctag,
        syncToken: syncToken,
        supportsVTodo: supportsVTodo,
        supportsVEvent: supportsVEvent,
        owner: owner,
      ));
    }
    return results;
  }

  static List<DavTaskResource> _parseTaskMultistatus(String xmlStr) {
    final doc = XmlDocument.parse(xmlStr);
    final multistatus = doc.rootElement;
    final results = <DavTaskResource>[];

    for (final response in multistatus.findElements('response', namespace: '*')) {
      final href = _childText(response, 'href');
      if (href == null) continue;

      final propstat = response.findElements('propstat', namespace: '*').firstOrNull;
      if (propstat == null) continue;

      final prop = propstat.findElements('prop', namespace: '*').firstOrNull;
      if (prop == null) continue;

      final etag = _childText(prop, 'getetag');
      final calendarData = _childText(prop, 'calendar-data');

      results.add(DavTaskResource(
        href: href,
        etag: etag,
        icalData: calendarData,
      ));
    }
    return results;
  }

  static String? _childText(XmlElement parent, String name) {
    final el = parent.findElements(name, namespace: '*').firstOrNull;
    return el?.innerText.trim();
  }
}
