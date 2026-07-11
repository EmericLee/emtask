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

  /// sync-collection REPORT（RFC 6578 增量同步）。
  ///
  /// [syncToken] 为上次同步获取的 token，传 null 或空字符串则全量拉取。
  /// 服务器返回变更/新增/删除的资源及新的 token。
  Future<SyncCollectionResult> syncCollection({
    required String calendarHref,
    required String? syncToken,
  }) async {
    final tokenElement = (syncToken != null && syncToken.isNotEmpty)
        ? '<d:sync-token>$syncToken</d:sync-token>'
        : '<d:sync-token/>';
    final body = '''<?xml version="1.0" encoding="UTF-8"?>
<d:sync-collection xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  $tokenElement
  <d:prop>
    <d:getetag/>
    <c:calendar-data/>
  </d:prop>
</d:sync-collection>''';
    final resp = await _send(
      method: CalDavMethod.report,
      path: calendarHref,
      body: body,
      contentType: 'application/xml; charset=utf-8',
    );
    return _parseSyncCollectionResponse(resp.body);
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
    // 优先从响应头获取 ETag；部分服务器（如 Nextcloud 204）不返回 ETag 头，
    // 回退到 PROPFIND 获取；仍获取失败则用 "*" 表示"资源存在时匹配"
    final etag = resp.headers['etag'] ?? await _fetchEtag(taskHref);
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
    final newEtag = resp.headers['etag'] ?? await _fetchEtag(taskHref);
    return newEtag;
  }

  /// 通过 PROPFIND 获取单个资源的 ETag（PUT 响应未返回 ETag 时的后备方案）。
  Future<String> _fetchEtag(String taskHref) async {
    try {
      final resp = await _send(
        method: CalDavMethod.propfind,
        path: taskHref,
        headers: {'Depth': '0'},
        body: '''<?xml version="1.0" encoding="UTF-8"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:getetag/>
  </d:prop>
</d:propfind>''',
        contentType: 'application/xml; charset=utf-8',
      );
      final resources = _parseTaskMultistatus(resp.body);
      if (resources.isNotEmpty && resources.first.etag != null) {
        return resources.first.etag!;
      }
    } catch (e) {
      AppLogger.instance.w(tag, 'PROPFIND 获取 ETag 失败: $e');
    }
    // 最终回退：* 表示"资源存在时匹配"
    AppLogger.instance.w(tag, '使用 * 作为 ETag 回退');
    return '*';
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
<d:propfind xmlns:d="DAV:" xmlns:cs="http://calendarserver.org/ns/" xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:nc="http://nextcloud.org/ns/" xmlns:oc="http://owncloud.org/ns/" xmlns:apple="http://apple.com/ns/ical/">
  <d:prop>
    <d:resourcetype/>
    <d:displayname/>
    <cs:getctag/>
    <d:sync-token/>
    <nc:color/>
    <apple:calendar-color/>
    <oc:calendar-enabled/>
    <c:supported-calendar-component-set/>
    <d:owner/>
  </d:prop>
</d:propfind>''';
  }

  static String _propfindCalendarPropsBody() {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<d:propfind xmlns:d="DAV:" xmlns:cs="http://calendarserver.org/ns/" xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:nc="http://nextcloud.org/ns/" xmlns:apple="http://apple.com/ns/ical/">
  <d:prop>
    <d:displayname/>
    <cs:getctag/>
    <d:sync-token/>
    <nc:color/>
    <apple:calendar-color/>
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

      // WebDAV 允许一个 response 包含多个 propstat（200 OK 和 404 Not Found），
      // 遍历所有 propstat 合并属性，避免遗漏分散在不同 propstat 中的属性。
      String? displayName;
      String? ctag;
      String? syncToken;
      String? color;
      String? owner;
      bool isCalendar = false;
      XmlElement? compSet;

      for (final propstat
          in response.findElements('propstat', namespace: '*')) {
        final prop = propstat.findElements('prop', namespace: '*').firstOrNull;
        if (prop == null) continue;

        final resourceType =
            prop.findElements('resourcetype', namespace: '*').firstOrNull;
        if (resourceType != null && !isCalendar) {
          isCalendar = resourceType
              .findElements('calendar', namespace: '*')
              .isNotEmpty;
        }

        displayName ??= _childText(prop, 'displayname');
        ctag ??= _childText(prop, 'getctag');
        syncToken ??= _childText(prop, 'sync-token');
        // 优先 nc:color，回退 apple:calendar-color
        color ??= _childText(prop, 'color') ??
            _childText(prop, 'calendar-color');
        owner ??= _childText(prop, 'owner');
        compSet ??= prop
            .findElements('supported-calendar-component-set', namespace: '*')
            .firstOrNull;
      }

      // 仅处理日历集合
      if (!isCalendar) continue;

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
        displayName: displayName ?? '',
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
      final prop = propstat?.findElements('prop', namespace: '*').firstOrNull;
      // 即使 prop/stat 为 null 也纳入资源（icalData 为 null 时由调用方 GET 补取）
      String? etag;
      String? calendarData;
      if (prop != null) {
        etag = _childText(prop, 'getetag');
        calendarData = _childText(prop, 'calendar-data');
      }

      results.add(DavTaskResource(
        href: href,
        etag: etag,
        icalData: calendarData,
      ));
    }
    return results;
  }

  /// 解析 sync-collection REPORT 响应。
  ///
  /// 响应格式与普通 multistatus 类似，但：
  /// - 根元素下有 `<sync-token>` 表示新令牌
  /// - 删除的资源以 `<response><status>404</status></response>` 表示（无 propstat）
  static SyncCollectionResult _parseSyncCollectionResponse(String xmlStr) {
    final doc = XmlDocument.parse(xmlStr);
    final multistatus = doc.rootElement;

    final resources = <DavTaskResource>[];
    final deletedHrefs = <String>[];

    for (final response in multistatus.findElements('response', namespace: '*')) {
      final href = _childText(response, 'href');
      if (href == null) continue;

      final propstat = response.findElements('propstat', namespace: '*').firstOrNull;
      if (propstat != null) {
        // 新增/更新的资源（即使 prop 为 null 也纳入，由调用方 GET 补取）
        final prop = propstat.findElements('prop', namespace: '*').firstOrNull;
        String? etag;
        String? calendarData;
        if (prop != null) {
          etag = _childText(prop, 'getetag');
          calendarData = _childText(prop, 'calendar-data');
        }
        resources.add(DavTaskResource(
          href: href,
          etag: etag,
          icalData: calendarData,
        ));
      } else {
        // 无 propstat，检查是否有 404 状态（删除的资源）
        final status = _childText(response, 'status');
        if (status != null && status.contains('404')) {
          deletedHrefs.add(href);
        }
      }
    }

    // 根元素下的 sync-token
    final newToken = _childText(multistatus, 'sync-token') ?? '';

    return SyncCollectionResult(
      resources: resources,
      deletedHrefs: deletedHrefs,
      syncToken: newToken,
    );
  }

  static String? _childText(XmlElement parent, String name) {
    final el = parent.findElements(name, namespace: '*').firstOrNull;
    return el?.innerText.trim();
  }
}
