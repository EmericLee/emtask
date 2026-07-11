import '../entities/calendar.dart';

/// 日历仓储抽象。
abstract class CalendarRepository {
  /// 获取所有已配置的日历
  Future<List<Calendar>> getAll();

  /// 监听日历列表变化
  Stream<List<Calendar>> watchAll();

  /// 按 URL 获取单个日历
  Future<Calendar?> getByUrl(String url);

  /// 从远端拉取日历列表并写入本地
  Future<List<Calendar>> refreshFromRemote();

  /// 更新日历的同步状态 / 颜色等
  Future<void> update(Calendar calendar);

  /// 启用 / 禁用某个日历的同步
  Future<void> setSyncEnabled(String url, bool enabled);

  /// 清除所有日历的 syncToken，强制下一次 pull 走全量拉取。
  Future<void> clearAllSyncTokens();
}
