import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'datasources/caldav/caldav_account.dart';
import 'datasources/caldav/caldav_client.dart';
import 'database/app_database.dart';
import 'repositories/calendar_repository_impl.dart';
import 'repositories/sync_repository_impl.dart';
import 'repositories/task_repository_impl.dart';
import '../domain/repositories/calendar_repository.dart';
import '../domain/repositories/sync_repository.dart';
import '../domain/repositories/task_repository.dart';
import 'settings/account_storage.dart';

/// SharedPreferences Provider。
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

/// 数据库 Provider（全局单例）。
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// 账户存储 Provider。
final accountStorageProvider = FutureProvider<AccountStorage>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return AccountStorage(prefs);
});

/// 当前已配置的 CalDAV 账户（可能为空）。
final currentAccountProvider = FutureProvider<CalDavAccount?>((ref) async {
  final storage = await ref.watch(accountStorageProvider.future);
  return storage.load();
});

/// CalDAV 客户端 Provider（依赖账户配置，未配置时为 null）。
final caldavClientProvider = Provider<CalDavClient?>((ref) {
  final account = ref.watch(currentAccountProvider).valueOrNull;
  if (account == null) return null;
  final client = CalDavClient(account: account);
  ref.onDispose(client.close);
  return client;
});

/// Task 仓储。
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return TaskRepositoryImpl(db);
});

/// Calendar 仓储。
final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final client = ref.watch(caldavClientProvider);
  if (client == null) {
    throw StateError('未配置 CalDAV 账户');
  }
  return CalendarRepositoryImpl(db: db, client: client);
});

/// Sync 仓储。
final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final client = ref.watch(caldavClientProvider);
  if (client == null) {
    throw StateError('未配置 CalDAV 账户，无法同步');
  }
  return SyncRepositoryImpl(db: db, client: client);
});
