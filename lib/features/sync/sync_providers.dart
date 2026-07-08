import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_logger.dart';
import '../../data/providers.dart';
import '../../domain/entities/calendar.dart';
import '../../domain/repositories/sync_repository.dart';
import '../tasks/task_providers.dart';

/// 同步检查间隔（分钟），控制 pull 定时检查频率，默认 10 分钟。
final autoSyncIntervalProvider = StateProvider<int>((ref) => 10);

/// 同步状态机。
class SyncState {
  const SyncState({
    this.running = false,
    this.lastResult,
    this.error,
    this.lastPushAt,
    this.lastPullAt,
  });

  final bool running;
  final SyncResult? lastResult;
  final String? error;

  /// 上次 push 完成时间。
  final DateTime? lastPushAt;

  /// 上次 pull 完成时间（用于判断是否需要再次 pull）。
  final DateTime? lastPullAt;

  SyncState copyWith({
    bool? running,
    SyncResult? lastResult,
    String? error,
    DateTime? lastPushAt,
    DateTime? lastPullAt,
  }) =>
      SyncState(
        running: running ?? this.running,
        lastResult: lastResult ?? this.lastResult,
        error: error,
        lastPushAt: lastPushAt ?? this.lastPushAt,
        lastPullAt: lastPullAt ?? this.lastPullAt,
      );
}

/// 同步状态 Notifier。
///
/// 同步策略：
/// 1. 有 dirty 任务时延时 10 秒后触发 push（防抖，避免频繁编辑多次上传）
/// 2. push 完成后，若距上次 pull 超过 5 分钟，触发 pull
/// 3. 每 [autoSyncIntervalProvider] 分钟（默认 10）定时检查，若距上次 pull
///    超过该间隔，触发 pull
/// 4. 通过 [running] 标志与 [_pushPending] 标志避免重复触发
class SyncNotifier extends Notifier<SyncState> {
  /// pull 定时检查器。
  Timer? _pullCheckTimer;

  /// push 防抖定时器。
  Timer? _pushDebounce;

  /// 是否已有 push 在防抖等待中（避免重复调度）。
  bool _pushPending = false;

  /// push 防抖延迟：dirty 出现后等待 10 秒再上传。
  static const _pushDebounceDelay = Duration(seconds: 10);

  /// push 后触发 pull 的阈值：距上次 pull 超过 5 分钟则拉取。
  static const _pullAfterPushThreshold = Duration(minutes: 5);

  @override
  SyncState build() {
    _startPullCheckTimer();
    // 监听 dirty 任务数变化，出现 dirty 即调度 push
    ref.listen(pendingSyncCountProvider, (previous, next) {
      final count = next.valueOrNull ?? 0;
      if (count > 0) _schedulePush();
    });
    ref.onDispose(() {
      _pullCheckTimer?.cancel();
      _pushDebounce?.cancel();
    });
    return const SyncState();
  }

  /// 启动/重启 pull 定时检查器。
  void _startPullCheckTimer() {
    _pullCheckTimer?.cancel();
    final interval = ref.read(autoSyncIntervalProvider);
    _pullCheckTimer = Timer.periodic(
      Duration(minutes: interval),
      (_) => _checkPull(),
    );
  }

  /// 供外部调用：间隔变更后重启定时器（不重置状态）。
  void restartAutoSyncTimer() => _startPullCheckTimer();

  // ---------------- 自动 push ----------------

  /// 调度一次防抖 push。若已有等待中的 push 则忽略（避免重复触发）。
  void _schedulePush() {
    if (_pushPending) return;
    _pushPending = true;
    _pushDebounce?.cancel();
    _pushDebounce = Timer(_pushDebounceDelay, () {
      _pushPending = false;
      _doPush();
    });
  }

  /// 执行 push（自动触发）。若当前正在同步则跳过，待操作完成后会基于 dirty
  /// 状态再次调度。
  Future<void> _doPush() async {
    if (state.running) return;
    state = state.copyWith(running: true, error: null);
    try {
      final syncRepo = ref.read(syncRepositoryProvider);
      final allDayDates = !ref.read(showTimeInDateFieldProvider);
      final result = await syncRepo.push(allDayDates: allDayDates);
      state = state.copyWith(
        running: false,
        lastResult: result,
        error: result.error?.toString(),
        lastPushAt: DateTime.now(),
      );
      AppLogger.instance.i('Sync', '自动 push 完成: $result');
      // push 后检查是否需要 pull
      _checkPullAfterPush();
      // 操作期间可能又产生了 dirty，若有则再次调度
      final stillDirty =
          (ref.read(pendingSyncCountProvider).valueOrNull ?? 0) > 0;
      if (stillDirty) _schedulePush();
    } catch (e) {
      state = state.copyWith(
        running: false,
        error: e.toString(),
        lastPushAt: DateTime.now(),
      );
      AppLogger.instance.w('Sync', '自动 push 失败: $e');
    }
  }

  // ---------------- 自动 pull ----------------

  /// push 完成后的 pull 检查：距上次 pull 超过 5 分钟则拉取。
  void _checkPullAfterPush() {
    if (state.running) return;
    final lastPull = state.lastPullAt;
    final needPull = lastPull == null ||
        DateTime.now().difference(lastPull) > _pullAfterPushThreshold;
    if (needPull) _doPull();
  }

  /// 定时 pull 检查：距上次 pull 超过检查间隔则拉取。
  void _checkPull() {
    if (state.running) return;
    final lastPull = state.lastPullAt;
    final threshold = Duration(minutes: ref.read(autoSyncIntervalProvider));
    final needPull = lastPull == null ||
        DateTime.now().difference(lastPull) > threshold;
    if (needPull) {
      AppLogger.instance.i('Sync', '定时检查触发 pull');
      _doPull();
    }
  }

  /// 执行 pull（自动触发）。若当前正在同步则跳过。
  Future<void> _doPull() async {
    if (state.running) return;
    state = state.copyWith(running: true, error: null);
    try {
      final syncRepo = ref.read(syncRepositoryProvider);
      final result = await syncRepo.pull();
      state = state.copyWith(
        running: false,
        lastResult: result,
        error: result.error?.toString(),
        lastPullAt: DateTime.now(),
      );
      AppLogger.instance.i('Sync', '自动 pull 完成: $result');
    } catch (e) {
      state = state.copyWith(
        running: false,
        error: e.toString(),
        lastPullAt: DateTime.now(),
      );
      AppLogger.instance.w('Sync', '自动 pull 失败: $e');
    }
  }

  // ---------------- 手动同步（UI 触发） ----------------

  /// 手动完整同步：push + pull。取消所有待执行的自动调度。
  Future<SyncResult> sync() async {
    _cancelPending();
    state = state.copyWith(running: true, error: null);
    try {
      final syncRepo = ref.read(syncRepositoryProvider);
      final allDayDates = !ref.read(showTimeInDateFieldProvider);
      final result = await syncRepo.sync(allDayDates: allDayDates);
      final now = DateTime.now();
      state = state.copyWith(
        running: false,
        lastResult: result,
        error: result.error?.toString(),
        lastPushAt: now,
        lastPullAt: now,
      );
      return result;
    } catch (e) {
      final now = DateTime.now();
      state = state.copyWith(
        running: false,
        error: e.toString(),
        lastPushAt: now,
        lastPullAt: now,
      );
      return SyncResult(error: e, finishedAt: DateTime.now().toUtc());
    }
  }

  /// 手动 push：取消自动调度后立即执行。
  Future<SyncResult> pushOnly() async {
    _cancelPending();
    state = state.copyWith(running: true, error: null);
    try {
      final syncRepo = ref.read(syncRepositoryProvider);
      final allDayDates = !ref.read(showTimeInDateFieldProvider);
      final result = await syncRepo.push(allDayDates: allDayDates);
      state = state.copyWith(
        running: false,
        lastResult: result,
        error: result.error?.toString(),
        lastPushAt: DateTime.now(),
      );
      return result;
    } catch (e) {
      state = state.copyWith(
        running: false,
        error: e.toString(),
        lastPushAt: DateTime.now(),
      );
      return SyncResult(error: e, finishedAt: DateTime.now().toUtc());
    }
  }

  /// 手动 pull：取消自动调度后立即执行。
  Future<SyncResult> pullOnly() async {
    _cancelPending();
    state = state.copyWith(running: true, error: null);
    try {
      final syncRepo = ref.read(syncRepositoryProvider);
      final result = await syncRepo.pull();
      state = state.copyWith(
        running: false,
        lastResult: result,
        error: result.error?.toString(),
        lastPullAt: DateTime.now(),
      );
      return result;
    } catch (e) {
      state = state.copyWith(
        running: false,
        error: e.toString(),
        lastPullAt: DateTime.now(),
      );
      return SyncResult(error: e, finishedAt: DateTime.now().toUtc());
    }
  }

  /// 取消待执行的自动调度（防抖 push）。
  void _cancelPending() {
    _pushDebounce?.cancel();
    _pushPending = false;
  }
}

/// 同步控制器。
final syncControllerProvider =
    NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);

/// 日历列表（响应式，用于 UI 显示）。
final calendarListProvider = StreamProvider<List<Calendar>>((ref) {
  final repo = ref.watch(calendarRepositoryProvider);
  return repo.watchAll();
});

/// 当前待同步任务数（响应式，dirty 或 deleted 任务总数）。
final pendingSyncCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchDirtyTaskCount();
});
