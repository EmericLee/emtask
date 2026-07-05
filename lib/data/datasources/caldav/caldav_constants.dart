/// CalDAV / WebDAV 协议相关常量与命名空间。
class CalDavNs {
  CalDavNs._();

  /// DAV 命名空间
  static const String dav = 'DAV:';

  /// CalDAV 命名空间
  static const String caldav = 'urn:ietf:params:xml:ns:caldav';

  /// CalDAV server namespace（calendarserver 扩展）
  static const String cs = 'http://calendarserver.org/ns/';

  /// Nextcloud 命名空间
  static const String nc = 'http://nextcloud.org/ns/';

  /// Apple iCal 命名空间
  static const String ical = 'http://apple.com/ns/ical/';
}

/// CalDAV HTTP 方法（非标准方法，需通过 [http.Client.send] 发送）。
class CalDavMethod {
  CalDavMethod._();

  static const String propfind = 'PROPFIND';
  static const String report = 'REPORT';
  static const String mkcalendar = 'MKCALENDAR';
}
