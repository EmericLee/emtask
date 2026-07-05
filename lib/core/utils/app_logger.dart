import 'dart:async';
import 'dart:collection';

/// 日志级别。
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

extension LogLevelX on LogLevel {
  String get label => switch (this) {
        LogLevel.debug => 'DEBUG',
        LogLevel.info => 'INFO ',
        LogLevel.warning => 'WARN ',
        LogLevel.error => 'ERROR',
      };

  String get emoji => switch (this) {
        LogLevel.debug => '🔍',
        LogLevel.info => 'ℹ️',
        LogLevel.warning => '⚠️',
        LogLevel.error => '❌',
      };
}

/// 单条日志记录。
class LogEntry {
  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.tag,
    this.error,
    this.stackTrace,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? tag;
  final Object? error;
  final StackTrace? stackTrace;

  String format() {
    final t = timestamp.toIso8601String().substring(0, 23);
    final tagStr = tag == null ? '' : '[$tag] ';
    return '$t ${level.label} $tagStr$message'
        '${error != null ? '\n  error: $error' : ''}';
  }
}

/// 全局日志服务（内存环形缓冲 + 广播流）。
///
/// 用法：
/// ```dart
/// AppLogger.instance.i('tag', 'message');
/// AppLogger.instance.e('tag', 'crash', error, stack);
/// ```
class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  static const int _maxLines = 2000;

  final Queue<LogEntry> _entries = Queue();
  final StreamController<LogEntry> _controller =
      StreamController<LogEntry>.broadcast();

  /// 日志流（UI 订阅）。
  Stream<LogEntry> get stream => _controller.stream;

  /// 当前全部日志（只读副本）。
  List<LogEntry> get entries => List.unmodifiable(_entries);

  /// 是否启用 debug 级别输出到 print。
  bool enablePrint = true;

  void _add(LogEntry e) {
    _entries.addLast(e);
    while (_entries.length > _maxLines) {
      _entries.removeFirst();
    }
    _controller.add(e);
    if (enablePrint) {
      // ignore: avoid_print
      print(e.format());
    }
  }

  void d(String tag, String message) =>
      _add(LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.debug,
        tag: tag,
        message: message,
      ));

  void i(String tag, String message) =>
      _add(LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.info,
        tag: tag,
        message: message,
      ));

  void w(String tag, String message, {Object? error}) =>
      _add(LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.warning,
        tag: tag,
        message: message,
        error: error,
      ));

  void e(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _add(LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.error,
        tag: tag,
        message: message,
        error: error,
        stackTrace: stackTrace,
      ));

  /// 清空日志。
  void clear() {
    _entries.clear();
  }
}
