import '../../core/utils/app_logger.dart';
import '../../domain/entities/calendar.dart';
import '../../domain/repositories/calendar_repository.dart';
import '../datasources/caldav/caldav_client.dart';
import '../datasources/caldav/caldav_models.dart';
import '../database/app_database.dart';

class CalendarRepositoryImpl implements CalendarRepository {
  CalendarRepositoryImpl({
    required AppDatabase db,
    required CalDavClient client,
  })  : _db = db,
        _client = client;

  final AppDatabase _db;
  final CalDavClient _client;

  static const String _tag = 'CalRepo';

  @override
  Future<List<Calendar>> getAll() => _db.getAllCalendars();

  @override
  Stream<List<Calendar>> watchAll() => _db.watchCalendars();

  @override
  Future<Calendar?> getByUrl(String url) => _db.getCalendarByUrl(url);

  @override
  Future<List<Calendar>> refreshFromRemote() async {
    AppLogger.instance.i(_tag, '从远端刷新日历列表…');
    final remoteList = await _client.listCalendars();
    AppLogger.instance.i(_tag, '远端返回 ${remoteList.length} 个日历');
    final result = <Calendar>[];
    for (final r in remoteList) {
      final absoluteUrl = _absoluteUrl(r.href);
      final existing = await _db.getCalendarByUrl(absoluteUrl);
      final cal = Calendar(
        localId: existing?.localId ?? 0,
        url: absoluteUrl,
        displayName: r.displayName,
        color: r.color ?? '#2E7D32',
        supportsTasks: r.supportsVTodo,
        supportsEvents: r.supportsVEvent,
        owner: r.owner ?? '',
        ctag: r.ctag,
        syncToken: r.syncToken,
        syncEnabled: existing?.syncEnabled ?? true,
      );
      await _db.upsertCalendar(cal);
      AppLogger.instance.d(_tag,
          '日历: ${cal.displayName}  url=$absoluteUrl  vtodo=${cal.supportsTasks}  sync=${cal.syncEnabled}');
      result.add(cal);
    }
    return result;
  }

  @override
  Future<void> update(Calendar calendar) => _db.upsertCalendar(calendar);

  @override
  Future<void> setSyncEnabled(String url, bool enabled) =>
      _db.setCalendarSyncEnabled(url, enabled);

  /// 将 HREF 转换为绝对 URL。
  ///
  /// 服务端返回的 href 通常是相对路径（如 `/remote.php/dav/calendars/user/cal/`），
  /// 这里使用 account.sanitizedBaseUrl 拼接为绝对 URL，作为本地数据库主键。
  String _absoluteUrl(String href) {
    if (href.startsWith('http://') || href.startsWith('https://')) {
      return href;
    }
    final base = _client.account.sanitizedBaseUrl;
    final p = href.startsWith('/') ? href : '/$href';
    return '$base$p';
  }
}

/// 将 [DavCalendarInfo] 转换为绝对 URL（占位，后续可扩展）。
String resolveCalendarUrl(DavCalendarInfo info, String baseUrl) {
  if (info.href.startsWith('http')) return info.href;
  final base = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  final p = info.href.startsWith('/') ? info.href : '/${info.href}';
  return '$base$p';
}
