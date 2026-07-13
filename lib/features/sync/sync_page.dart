import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_logger.dart';
import '../../data/datasources/caldav/caldav_account.dart';
import '../../data/datasources/caldav/connection_test_result.dart';
import '../../data/providers.dart';
import '../diagnostics/diagnostics_providers.dart';
import 'sync_providers.dart';

/// 同步页：账户配置 + 同步状态 + 连接测试 + 同步设置。
/// 日志通过 AppBar 按钮以弹窗形式打开。
class SyncPage extends ConsumerStatefulWidget {
  const SyncPage({super.key});

  @override
  ConsumerState<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends ConsumerState<SyncPage> {
  // — 账户配置 —
  final _urlCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _trustCert = false;
  bool _saving = false;
  bool _hasAccount = false; // 已有账户时显示缩略信息

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    final storage = await ref.read(accountStorageProvider.future);
    final acc = await storage.load();
    if (acc != null && mounted) {
      setState(() {
        _urlCtrl.text = acc.baseUrl;
        _userCtrl.text = acc.username;
        _passCtrl.text = acc.password;
        _nameCtrl.text = acc.displayName ?? '';
        _trustCert = acc.trustSelfSignedCert;
        _hasAccount = true;
      });
    }
  }

  Future<void> _saveAccount() async {
    setState(() => _saving = true);
    try {
      final account = CalDavAccount(
        baseUrl: _urlCtrl.text.trim().replaceAll(RegExp(r'/+$'), ''),
        username: _userCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        displayName: _nameCtrl.text.trim().isEmpty
            ? null
            : _nameCtrl.text.trim(),
        trustSelfSignedCert: _trustCert,
      );
      final storage = await ref.read(accountStorageProvider.future);
      await storage.save(account);
      ref.invalidate(currentAccountProvider);
      if (mounted) {
        setState(() => _hasAccount = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存账户配置')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(syncControllerProvider);
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final testState = ref.watch(connectionTestProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('同步'),
        actions: [
          IconButton(
            icon: const Icon(Icons.terminal),
            tooltip: '日志',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const _LogDialog(),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // — 账户配置 —
          const _SectionTitle(title: 'CalDAV 账户'),
          const SizedBox(height: 8),
          if (_hasAccount)
            _buildAccountSummary(theme)
          else
            _buildAccountForm(),
          const SizedBox(height: 24),

          // — 同步状态 —
          const _SectionTitle(title: '同步状态'),
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: state.running
                ? null
                : () => ref.read(syncControllerProvider.notifier).sync(),
            icon: const Icon(Icons.sync),
            label: const Text('立即同步'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: state.running
                ? null
                : () => ref.read(syncControllerProvider.notifier).fullSync(),
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
                      : () => ref
                          .read(syncControllerProvider.notifier)
                          .pushOnly(),
                  icon: const Icon(Icons.upload),
                  label: const Text('仅上传'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state.running
                      ? null
                      : () => ref
                          .read(syncControllerProvider.notifier)
                          .pullOnly(),
                  icon: const Icon(Icons.download),
                  label: const Text('仅下载'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // — 连接测试 —
          const _SectionTitle(title: '连接测试'),
          const SizedBox(height: 8),
          Card(
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
                          style: theme.textTheme.titleMedium),
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
                  FilledButton.tonalIcon(
                    onPressed: testState.running
                        ? null
                        : () => ref
                            .read(connectionTestProvider.notifier)
                            .run(),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('运行测试'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // — 同步设置 —
          const _SectionTitle(title: '同步设置'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _AutoSyncIntervalSelector(ref: ref),
            ),
          ),
        ],
      ),
    );
  }

  /// 账户缩略信息卡片
  Widget _buildAccountSummary(ThemeData theme) {
    final name = _nameCtrl.text.trim().isEmpty
        ? _userCtrl.text.trim()
        : _nameCtrl.text.trim();
    final url = _urlCtrl.text.trim();
    // 截断过长的 URL
    final displayUrl = url.length > 40 ? '${url.substring(0, 37)}...' : url;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _userCtrl.text.trim(),
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayUrl,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: '编辑账户',
              onPressed: () => setState(() => _hasAccount = false),
            ),
          ],
        ),
      ),
    );
  }

  /// 账户编辑表单
  Widget _buildAccountForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: '服务器地址',
                hintText: 'https://cloud.example.com',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _userCtrl,
              decoration: const InputDecoration(
                labelText: '用户名',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(
                labelText: '应用密码',
                helperText: 'Nextcloud：在「安全」设置中生成应用密码',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '显示名称（可选）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('信任自签名证书'),
              subtitle: const Text('内网 / UOS 本地部署常用'),
              value: _trustCert,
              onChanged: (v) => setState(() => _trustCert = v),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (_hasAccount)
                  TextButton.icon(
                    onPressed: () => setState(() => _hasAccount = true),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('取消'),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveAccount,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 区块标题
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
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

/// 连接测试结果展示
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

/// 同步检查间隔选择器
class _AutoSyncIntervalSelector extends StatelessWidget {
  const _AutoSyncIntervalSelector({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final interval = ref.watch(autoSyncIntervalProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('同步检查间隔', style: theme.textTheme.bodyMedium),
            ),
            DropdownButton<int>(
              value: interval,
              items: const [
                DropdownMenuItem(value: 5, child: Text('5 分钟')),
                DropdownMenuItem(value: 10, child: Text('10 分钟')),
                DropdownMenuItem(value: 15, child: Text('15 分钟')),
                DropdownMenuItem(value: 30, child: Text('30 分钟')),
              ],
              onChanged: (v) {
                if (v != null) {
                  ref.read(autoSyncIntervalProvider.notifier).state = v;
                  ref.read(syncControllerProvider.notifier).restartAutoSyncTimer();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'dirty 任务 10 秒后自动上传；上传后 5 分钟未拉取则拉取；'
          '超过此处设置的间隔未拉取则强制拉取。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  日志弹窗
// ════════════════════════════════════════════════════════════════

/// 日志弹窗：独立 StatefulWidget，自行订阅日志流。
/// 使用 SelectionArea 包裹列表，支持跨行选择。
class _LogDialog extends StatefulWidget {
  const _LogDialog();

  @override
  State<_LogDialog> createState() => _LogDialogState();
}

class _LogDialogState extends State<_LogDialog> {
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
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text('日志 (${_logs.length})',
                      style: theme.textTheme.titleMedium),
                  const Spacer(),
                  if (_logs.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.cleaning_services_outlined,
                          size: 20),
                      tooltip: '清空日志',
                      onPressed: () => setState(() {
                        AppLogger.instance.clear();
                        _logs.clear();
                      }),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // 工具栏
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text('自动滚动', style: theme.textTheme.bodySmall),
                  const Spacer(),
                  Switch(
                    value: _autoScroll,
                    onChanged: (v) => setState(() => _autoScroll = v),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 日志列表 — SelectionArea 支持跨行选择
            Expanded(
              child: _logs.isEmpty
                  ? const Center(
                      child: Text('暂无日志',
                          style: TextStyle(color: Colors.grey)))
                  : SelectionArea(
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        itemCount: _logs.length,
                        itemBuilder: (context, i) =>
                            _LogTile(entry: _logs[i]),
                      ),
                    ),
            ),
          ],
        ),
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
      child: Text.rich(
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
