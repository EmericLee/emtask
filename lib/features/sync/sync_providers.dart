import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/entities/calendar.dart';
import '../../domain/repositories/sync_repository.dart';

/// 同步状态机。
class SyncState {
  const SyncState({
    this.running = false,
    this.lastResult,
    this.error,
  });

  final bool running;
  final SyncResult? lastResult;
  final String? error;

  SyncState copyWith({
    bool? running,
    SyncResult? lastResult,
    String? error,
  }) =>
      SyncState(
        running: running ?? this.running,
        lastResult: lastResult ?? this.lastResult,
        error: error,
      );
}

/// 同步状态 Notifier。
class SyncNotifier extends Notifier<SyncState> {
  @override
  SyncState build() => const SyncState();

  Future<void> sync() async {
    state = state.copyWith(running: true, error: null);
    try {
      final syncRepo = ref.read(syncRepositoryProvider);
      final result = await syncRepo.sync();
      state = state.copyWith(running: false, lastResult: result);
    } catch (e) {
      state = state.copyWith(running: false, error: e.toString());
    }
  }

  Future<void> pushOnly() async {
    state = state.copyWith(running: true, error: null);
    try {
      final syncRepo = ref.read(syncRepositoryProvider);
      final result = await syncRepo.push();
      state = state.copyWith(running: false, lastResult: result);
    } catch (e) {
      state = state.copyWith(running: false, error: e.toString());
    }
  }

  Future<void> pullOnly() async {
    state = state.copyWith(running: true, error: null);
    try {
      final syncRepo = ref.read(syncRepositoryProvider);
      final result = await syncRepo.pull();
      state = state.copyWith(running: false, lastResult: result);
    } catch (e) {
      state = state.copyWith(running: false, error: e.toString());
    }
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

/// 当前 dirty 任务数（用于显示待同步数量）。
final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final dirty = await db.getDirtyTasks();
  final deleted = await db.getDeletedTasks();
  return dirty.length + deleted.length;
});
