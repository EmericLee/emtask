import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_logger.dart';
import '../../data/datasources/caldav/connection_test_result.dart';
import 'diagnostics_providers.dart';

/// 诊断页：连接测试 + 实时日志查看。
class DiagnosticsPage extends ConsumerStatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  ConsumerState<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends ConsumerState<DiagnosticsPage> {
  StreamSubscription<LogEntry>? _sub;
  final List<LogEntry> _logs = [];
  bool _autoScroll = true;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _logs.addAll(AppLogger.instance.entries);
    _sub = AppLogger.instance.stream.listen((e) {
      if (!mounted) return;
      setState(() => _logs.add(e));
      if (_autoScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final testState = ref.watch(connectionTestProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('诊断'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: '清空日志',
            onPressed: () => setState(() {
              AppLogger.instance.clear();
              _logs.clear();
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          // 连接测试面板
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.network_check, size: 20),
                      const SizedBox(width: 8),
                      Text('Nextcloud 连接测试',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      if (testState.running)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (testState.result != null)
                    _ResultView(result: testState.result!)
                  else if (testState.error != null)
                    Text('错误：${testState.error}',
                        style: const TextStyle(color: Colors.red))
                  else
                    const Text('点击下方按钮测试与 Nextcloud 的连接。'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: testState.running
                            ? null
                            : () => ref
                                .read(connectionTestProvider.notifier)
                                .run(),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('运行测试'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {}),
                        icon: const Icon(Icons.refresh),
                        label: const Text('刷新日志'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 日志面板
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text('日志 (${_logs.length})',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                const Text('自动滚动'),
                Switch(
                  value: _autoScroll,
                  onChanged: (v) => setState(() => _autoScroll = v),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: _logs.length,
              itemBuilder: (context, i) {
                final e = _logs[i];
                return _LogTile(entry: e);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});
  final ConnectionTestResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _step('1. 基础连通 (GET /status.php)', result.step1Ping, result.success),
        _step('2. 列出日历 (PROPFIND)', result.step2Calendars, result.success),
        _step('3. 查询 VTODO (REPORT)', result.step3VTodos, result.success),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              result.success ? Icons.check_circle : Icons.cancel,
              color: result.success ? Colors.green : Colors.red,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(result.success ? '测试通过' : '测试失败',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: result.success ? Colors.green : Colors.red,
                )),
            if (result.elapsedMs > 0)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text('${result.elapsedMs}ms',
                    style: const TextStyle(color: Colors.grey)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _step(String title, String? content, bool success) {
    final ok = content == null ? null : !content.startsWith('FAIL');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok == null ? Icons.remove : (ok ? Icons.check : Icons.close),
            size: 16,
            color: ok == null ? Colors.grey : (ok ? Colors.green : Colors.red),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (content != null)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SelectableText(
                      content,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});
  final LogEntry entry;

  Color _color() => switch (entry.level) {
        LogLevel.debug => Colors.grey,
        LogLevel.info => Colors.blue,
        LogLevel.warning => Colors.orange,
        LogLevel.error => Colors.red,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: SelectableText.rich(
        TextSpan(
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Colors.black87,
            height: 1.3,
          ),
          children: [
            TextSpan(
              text: '${entry.timestamp.toIso8601String().substring(11, 23)} ',
              style: TextStyle(color: _color(), fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: '${entry.level.label} ',
              style: TextStyle(color: _color(), fontWeight: FontWeight.bold),
            ),
            if (entry.tag != null)
              TextSpan(
                text: '[${entry.tag}] ',
                style: const TextStyle(color: Colors.purple),
              ),
            TextSpan(text: entry.message),
            if (entry.error != null)
              TextSpan(
                text: '\n  ↳ ${entry.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
          ],
        ),
      ),
    );
  }
}
