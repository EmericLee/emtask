import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_logger.dart';
import '../../data/datasources/caldav/caldav_client.dart';
import '../../data/datasources/caldav/connection_test_result.dart';
import '../../data/providers.dart';

/// 连接测试状态。
class ConnectionTestState {
  const ConnectionTestState({
    this.running = false,
    this.result,
    this.error,
  });

  final bool running;
  final ConnectionTestResult? result;
  final String? error;

  ConnectionTestState copyWith({
    bool? running,
    ConnectionTestResult? result,
    String? error,
  }) =>
      ConnectionTestState(
        running: running ?? this.running,
        result: result ?? this.result,
        error: error,
      );
}

/// 连接测试 Notifier。
class ConnectionTestNotifier extends Notifier<ConnectionTestState> {
  @override
  ConnectionTestState build() => const ConnectionTestState();

  /// 运行连接测试。
  ///
  /// 若当前未配置账户，会构造一个临时 CalDavClient 进行测试（避免影响主 client）。
  Future<void> run() async {
    state = const ConnectionTestState(running: true);

    try {
      final account = ref.read(currentAccountProvider).valueOrNull;
      if (account == null) {
        state = const ConnectionTestState(
          error: '未配置账户，请先在「设置」中填写并保存。',
        );
        return;
      }

      // 用临时 client，避免污染主 provider 的 client 生命周期
      final client = CalDavClient(account: account);
      try {
        final sw = Stopwatch()..start();
        AppLogger.instance.i('Test', '启动连接测试: ${account.baseUrl}');
        final result = await client.testConnection();
        result.elapsedMs = sw.elapsedMilliseconds;
        state = ConnectionTestState(result: result);
      } finally {
        client.close();
      }
    } catch (e, s) {
      AppLogger.instance.e('Test', '连接测试异常', error: e, stackTrace: s);
      state = ConnectionTestState(error: '$e');
    }
  }
}

/// 连接测试 Provider。
final connectionTestProvider =
    NotifierProvider<ConnectionTestNotifier, ConnectionTestState>(
  ConnectionTestNotifier.new,
);
