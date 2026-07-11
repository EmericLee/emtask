import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_logger.dart';
import '../../data/providers.dart';
import 'sync_providers.dart';

/// 同步页：显示同步状态、手动同步、上次结果、实时日志。
class SyncPage extends ConsumerStatefulWidget {
  const SyncPage({super.key});

  @override
  ConsumerState<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends ConsumerState<SyncPage> {
  StreamSubscription<LogEntry>? _sub;
  final List<LogEntry> _logs = [];
  bool _autoScroll = true;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    // 仅展示 Sync / CalDav / CalRepo / Test 标签的日志
    const tags = {'Sync', 'CalDav', 'CalRepo', 'Test'};
    _logs.addAll(AppLogger.instance.entries.where((e) => tags.contains(e.tag)));
    _sub = AppLogger.instance.stream.listen((e) {
      if (!mounted) return;
      if (!tags.contains(e.tag)) return;
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
    final state = ref.watch(syncControllerProvider);
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('同步')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              state.running
                                  ? Icons.sync
                                  : Icons.cloud_done_outlined,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                state.running ? '同步中…' : '同步就绪',
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _StatRow(label: '待上传', value: '$pending'),
                        if (state.lastResult != null) ...[
                          const Divider(),
                          _StatRow(
                              label: '上次上传',
                              value: '${state.lastResult!.uploaded}'),
                          _StatRow(
                              label: '上次下载',
                              value: '${state.lastResult!.downloaded}'),
                          _StatRow(
                              label: '上次删除',
                              value: '${state.lastResult!.deleted}'),
                        ],
                        if (state.error != null) ...[
                          const Divider(),
                          Text(
                            '错误：${state.error}',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: state.running
                      ? null
                      : () =>
                          ref.read(syncControllerProvider.notifier).sync(),
                  icon: const Icon(Icons.sync),
                  label: const Text('立即同步'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: state.running
                      ? null
                      : () =>
                          ref.read(syncControllerProvider.notifier).fullSync(),
                  icon: const Icon(Icons.sync_problem),
                  label: const Text('全量同步'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: state.running
                            ? null
                            : () =>
                                ref.read(syncControllerProvider.notifier).pushOnly(),
                        icon: const Icon(Icons.upload),
                        label: const Text('仅上传'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: state.running
                            ? null
                            : () =>
                                ref.read(syncControllerProvider.notifier).pullOnly(),
                        icon: const Icon(Icons.download),
                        label: const Text('仅下载'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // 账户状态
                FutureBuilder(
                  future: ref.watch(currentAccountProvider.future),
                  builder: (context, snapshot) {
                    final account = snapshot.data;
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.account_circle),
                        title: Text(account?.displayName ??
                            account?.username ??
                            '未配置账户'),
                        subtitle: Text(account?.baseUrl ??
                            '请在「设置」中配置 CalDAV 账户'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                // 日志面板
                Row(
                  children: [
                    Text('同步日志 (${_logs.length})',
                        style: theme.textTheme.titleMedium),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.cleaning_services_outlined,
                          size: 20),
                      tooltip: '清空日志',
                      onPressed: () => setState(() {
                        AppLogger.instance.clear();
                        _logs.clear();
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          // 日志列表（固定高度，可滚动）
          Container(
            height: 280,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              border: Border(
                top: BorderSide(color: theme.dividerColor),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      const Text('自动滚动'),
                      const Spacer(),
                      Switch(
                        value: _autoScroll,
                        onChanged: (v) => setState(() => _autoScroll = v),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _logs.isEmpty
                      ? const Center(
                          child: Text('暂无日志',
                              style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          itemCount: _logs.length,
                          itemBuilder: (context, i) =>
                              _LogTile(entry: _logs[i]),
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

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
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
            fontSize: 11,
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
