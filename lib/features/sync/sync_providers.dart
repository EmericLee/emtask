import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_logger.dart';
import '../../data/providers.dart';
import '../../domain/entities/calendar.dart';
import '../../domain/repositories/sync_repository.dart';
import '../tasks/task_providers.dart';

final autoSyncIntervalProvider = StateProvider<int>((ref) => 10);

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
  final DateTime? lastPushAt;
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

class SyncNotifier extends Notifier<SyncState> {
  Timer? _pullCheckTimer;
  Timer? _pushDebounce;
  bool _pushPending = false;
  bool _isPushing = false;
  static const _pushDebounceDelay = Duration(seconds: 10);

  @override
  SyncState build() {
    _startPullCheckTimer();
    _scheduleInitialSync();
    ref.listen(pendingSyncCountProvider, (previous, next) {
      if (_isPushing) return;
      final count = next.valueOrNull ?? 0;
      if (count > 0) _schedulePush();
    });
    ref.onDispose(() {
      _pullCheckTimer?.cancel();
      _pushDebounce?.cancel();
    });
    return const SyncState();
  }

  void _scheduleInitialSync() {
    Timer(const Duration(seconds: 2), () async {
      if (state.running) return;
      final db = ref.read(appDatabaseProvider);
      final dirtyTasks = await db.getDirtyTasks();
      final deletedTasks = await db.getDeletedTasks();
      if (dirtyTasks.isEmpty && deletedTasks.isEmpty) {
        AppLogger.instance.i('Sync', '━━━━ 同步任务 [启动触发] ━━━━');
        AppLogger.instance.i('Sync', '启动时无 dirty 任务，跳过 push，执行 pull');
        _doPull(trigger: '启动触发');
        return;
      }
      AppLogger.instance.i('Sync', '━━━━ 同步任务 [启动触发] ━━━━');
      AppLogger.instance.i('Sync', '启动检测到 ${dirtyTasks.length} 个 dirty 任务，执行 push');
      _pushPending = true;
      _doPush(trigger: '启动触发');
    });
  }

  void _startPullCheckTimer() {
    _pullCheckTimer?.cancel();
    final interval = ref.read(autoSyncIntervalProvider);
    _pullCheckTimer = Timer.periodic(
      Duration(minutes: interval),
      (_) => _checkPull(),
    );
  }

  void restartAutoSyncTimer() => _startPullCheckTimer();

  void _schedulePush() {
    if (_pushPending) return;
    _pushPending = true;
    _pushDebounce?.cancel();
    _pushDebounce = Timer(_pushDebounceDelay, () {
      _pushPending = false;
      _doPush();
    });
  }

  Future<void> _doPush({String trigger = '编辑触发'}) async {
    if (state.running) {
      _schedulePush();
      return;
    }
    // 提前设置 _isPushing，防止 dirty 检查的 await 期间定时 pull 插入。
    _isPushing = true;
    final db = ref.read(appDatabaseProvider);
    final dirtyTasks = await db.getDirtyTasks();
    final deletedTasks = await db.getDeletedTasks();
    if (dirtyTasks.isEmpty && deletedTasks.isEmpty) {
      _isPushing = false;
      AppLogger.instance.d('Sync', '无待同步任务，跳过 push');
      return;
    }
    state = state.copyWith(running: true, error: null);
    try {
      AppLogger.instance.i('Sync', '━━━━ push [$trigger] ━━━━');
      final syncRepo = ref.read(syncRepositoryProvider);
      final allDayDates = !ref.read(showTimeInDateFieldProvider);

      // 循环 push 直到无 dirty 或失败。
      // push 期间用户可能继续编辑产生新的 dirty，循环确保全部上传完成后才 pull。
      var totalUploaded = 0;
      var totalDeleted = 0;
      Object? pushError;
      while (true) {
        final dirty = await db.getDirtyTasks();
        final deleted = await db.getDeletedTasks();
        if (dirty.isEmpty && deleted.isEmpty) break;

        final result = await syncRepo.push(allDayDates: allDayDates);
        totalUploaded += result.uploaded;
        totalDeleted += result.deleted;

        if (result.error != null) {
          pushError = result.error;
          break;
        }
      }

      state = state.copyWith(
        lastResult: SyncResult(
          uploaded: totalUploaded,
          deleted: totalDeleted,
          error: pushError,
          finishedAt: DateTime.now().toUtc(),
        ),
        error: pushError?.toString(),
        lastPushAt: DateTime.now(),
      );

      // push 失败则不 pull，避免用远端数据覆盖本地未上传的修改。
      if (pushError != null) {
        AppLogger.instance.w('Sync', 'push 失败，跳过 pull');
        state = state.copyWith(running: false);
        return;
      }

      // 所有 dirty 完成后，自动进行一次 pull：
      // - 刷新日历 syncToken，避免下次 pull 重复下载刚 push 的任务
      // - 拉取其他客户端在此期间的修改
      // 整个 push+pull 流程保持 running=true，不会被定时器打断。
      AppLogger.instance.i('Sync', '━━━━ pull [push后触发] ━━━━');
      final pullResult = await _executePullCore();
      state = state.copyWith(
        running: false,
        lastResult: pullResult,
        error: pullResult.error?.toString(),
        lastPullAt: DateTime.now(),
      );

      // pull 完成后重置自动 pull 计时器，下次定时 pull 从新基准开始计时。
      _startPullCheckTimer();
    } catch (e) {
      state = state.copyWith(
        running: false,
        error: e.toString(),
        lastPushAt: DateTime.now(),
      );
      AppLogger.instance.w('Sync', '自动 push 失败: $e');
    } finally {
      _isPushing = false;
      _pushPending = false;
    }
  }

  void _checkPull() {
    // push 进行中时跳过，避免与 push+pull 流程冲突。
    // _isPushing 在 _doPush 入口就设置，覆盖 dirty 检查期间的竞态窗口。
    if (state.running || _isPushing) return;
    final lastPull = state.lastPullAt;
    final threshold = Duration(minutes: ref.read(autoSyncIntervalProvider));
    final needPull = lastPull == null ||
        DateTime.now().difference(lastPull) > threshold;
    if (needPull) {
      _doPull(trigger: '定时触发');
    }
  }

  /// pull 的核心逻辑，不管理 running 状态。
  /// 调用方（_doPull 或 _doPush）负责设置和重置 running。
  Future<SyncResult> _executePullCore() async {
    final syncRepo = ref.read(syncRepositoryProvider);
    return await syncRepo.pull();
  }

  Future<void> _doPull({String trigger = '自动触发'}) async {
    if (state.running) return;
    state = state.copyWith(running: true, error: null);
    try {
      AppLogger.instance.i('Sync', '━━━━ pull [$trigger] ━━━━');
      final result = await _executePullCore();
      state = state.copyWith(
        running: false,
        lastResult: result,
        error: result.error?.toString(),
        lastPullAt: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        running: false,
        error: e.toString(),
        lastPullAt: DateTime.now(),
      );
      AppLogger.instance.w('Sync', '自动 pull 失败: $e');
    }
  }

  Future<SyncResult> sync() async {
    _cancelPending();
    state = state.copyWith(running: true, error: null);
    try {
      AppLogger.instance.i('Sync', '━━━━ 完整同步 [手动触发] ━━━━');
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

  Future<SyncResult> fullSync() async {
    _cancelPending();
    state = state.copyWith(running: true, error: null);
    try {
      AppLogger.instance.i('Sync', '━━━━ 全量同步 [手动触发] ━━━━');
      final syncRepo = ref.read(syncRepositoryProvider);
      final allDayDates = !ref.read(showTimeInDateFieldProvider);
      final result = await syncRepo.fullSync(allDayDates: allDayDates);
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

  Future<SyncResult> pushOnly() async {
    _cancelPending();
    state = state.copyWith(running: true, error: null);
    try {
      AppLogger.instance.i('Sync', '━━━━ push [手动触发] ━━━━');
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

  Future<SyncResult> pullOnly() async {
    _cancelPending();
    state = state.copyWith(running: true, error: null);
    try {
      AppLogger.instance.i('Sync', '━━━━ pull [手动触发] ━━━━');
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

  void _cancelPending() {
    _pushDebounce?.cancel();
    _pushPending = false;
  }
}

final syncControllerProvider =
    NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);

final calendarListProvider = StreamProvider<List<Calendar>>((ref) {
  final repo = ref.watch(calendarRepositoryProvider);
  return repo.watchAll();
});

final pendingSyncCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchDirtyTaskCount();
});
