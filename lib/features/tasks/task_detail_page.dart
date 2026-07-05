import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/providers.dart';
import '../../domain/entities/calendar.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_status.dart';
import '../sync/sync_providers.dart';

/// 任务详情 / 编辑页。
///
/// 默认进入查看模式，点击编辑按钮切换为编辑模式。
/// 当 [taskId] 为 "new" 时直接进入新建模式。
class TaskDetailPage extends ConsumerStatefulWidget {
  const TaskDetailPage({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  late final bool _isNew = widget.taskId == 'new';
  bool _editing = false;

  final _summaryCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  DateTime? _due;
  DateTime? _start;
  TaskStatus _status = TaskStatus.needsAction;
  TaskPriority _priority = TaskPriority.none;
  int _percent = 0;
  String? _calendarUrl;
  List<String> _categories = [];
  Task? _loaded;

  @override
  void initState() {
    super.initState();
    _editing = _isNew;
    if (!_isNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    final id = int.tryParse(widget.taskId);
    if (id == null) return;
    final repo = ref.read(taskRepositoryProvider);
    final all = await repo.getAll();
    final t = all.firstWhere(
      (x) => x.localId == id,
      orElse: () => throw StateError('任务不存在'),
    );
    setState(() {
      _loaded = t;
      _summaryCtrl.text = t.summary;
      _descCtrl.text = t.description;
      _categoryCtrl.text = t.categories.join(', ');
      _due = t.due;
      _start = t.start;
      _status = t.status;
      _priority = t.priority;
      _percent = t.percent;
      _categories = List.of(t.categories);
      _calendarUrl = t.calendarUrl;
    });
  }

  @override
  void dispose() {
    _summaryCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_summaryCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入任务标题')),
      );
      return;
    }
    final repo = ref.read(taskRepositoryProvider);
    if (_isNew) {
      final cal = _calendarUrl ?? (await _firstCalendarUrl());
      if (cal == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先在设置中配置 CalDAV 账户')),
          );
        }
        return;
      }
      await repo.create(
        Task.create(
          calendarUrl: cal,
          summary: _summaryCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          due: _due,
          start: _start,
          status: _status,
          priority: _priority,
          categories: _categories,
        ),
      );
    } else if (_loaded != null) {
      // 同步完成状态
      final completed = _status == TaskStatus.completed
          ? (_loaded!.completed ?? DateTime.now().toUtc())
          : null;
      await repo.update(
        _loaded!.copyWith(
          summary: _summaryCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          due: _due,
          start: _start,
          status: _status,
          priority: _priority,
          percent: _percent,
          categories: _categories,
          completed: completed,
          lastModified: DateTime.now().toUtc(),
        ),
      );
    }
    if (mounted) {
      setState(() => _editing = false);
      if (_isNew) context.go('/tasks');
    }
  }

  Future<String?> _firstCalendarUrl() async {
    final repo = ref.read(calendarRepositoryProvider);
    final list = await repo.getAll();
    return list.isEmpty ? null : list.first.url;
  }

  Future<void> _delete() async {
    if (_loaded == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确定要删除「${_loaded!.summary}」吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = ref.read(taskRepositoryProvider);
    await repo.delete(_loaded!.uid);
    if (mounted) context.go('/tasks');
  }

  @override
  Widget build(BuildContext context) {
    final calendarsAsync = ref.watch(calendarListProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/tasks'),
        ),
        title: Text(_isNew
            ? '新建任务'
            : _editing
                ? '编辑任务'
                : '任务详情'),
        actions: [
          if (!_isNew && !_editing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _editing = true),
              tooltip: '编辑',
            )
          else if (!_isNew && _editing)
            IconButton(
              icon: const Icon(Icons.visibility_outlined),
              onPressed: () {
                setState(() => _editing = false);
                _load(); // 丢弃修改重新加载
              },
              tooltip: '取消编辑',
            ),
          if (!_isNew && _editing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
              tooltip: '删除',
            ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
            tooltip: '保存',
          ),
        ],
      ),
      body: _editing
          ? _buildEditView(calendarsAsync)
          : _buildReadView(calendarsAsync),
    );
  }

  // ==================== 查看模式 ====================

  Widget _buildReadView(AsyncValue calendarsAsync) {
    final t = _loaded;
    if (t == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final theme = Theme.of(context);
    final fmt = DateFormat('yyyy-MM-dd HH:mm');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 标题
        Text(
          t.summary,
          style: theme.textTheme.headlineSmall?.copyWith(
            decoration: t.isCompleted ? TextDecoration.lineThrough : null,
            color: t.isCompleted ? theme.colorScheme.outline : null,
          ),
        ),
        const SizedBox(height: 8),
        // 状态标签行
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _InfoChip(
              icon: _statusIcon(t.status),
              label: _statusLabel(t.status),
              color: _statusColor(t.status, theme),
            ),
            if (t.priority != TaskPriority.none)
              _InfoChip(
                icon: Icons.flag_outlined,
                label: '优先级 ${_priorityLabel(t.priority)}',
                color: _priorityColor(t.priority),
              ),
            if (t.percent > 0)
              _InfoChip(
                icon: Icons.percent_outlined,
                label: '进度 ${t.percent}%',
                color: theme.colorScheme.secondary,
              ),
          ],
        ),
        const SizedBox(height: 16),
        // 描述
        if (t.description.trim().isNotEmpty) ...[
          Text('描述', style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              t.description,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 16),
        ],
        // 分类标签
        if (t.categories.isNotEmpty) ...[
          Text('分类', style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: t.categories
                .map((c) => Chip(
                      avatar: const Icon(Icons.label_outline, size: 16),
                      label: Text(c),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
        // 时间信息
        Text('时间', style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary)),
        const SizedBox(height: 4),
        Card(
          child: Column(
            children: [
              _timeTile('开始', t.start, fmt),
              _timeTile('截止', t.due, fmt, highlight: t.isOverdue),
              _timeTile('完成', t.completed, fmt),
              _timeTile('创建', t.created, fmt),
              _timeTile('最后修改', t.lastModified, fmt),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 所属日历
        Text('所属清单', style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary)),
        const SizedBox(height: 4),
        calendarsAsync.when(
          data: (list) {
            final cal = list.firstWhere(
              (c) => c.url == t.calendarUrl,
              orElse: () => Calendar(
                localId: 0,
                url: t.calendarUrl,
                displayName: t.calendarUrl,
                color: '',
                supportsTasks: true,
                supportsEvents: false,
                owner: '',
                syncEnabled: true,
              ),
            );
            return Card(
              child: ListTile(
                leading: Icon(Icons.calendar_today_outlined,
                    color: _parseColor(cal.color)),
                title: Text(cal.displayName),
                subtitle: Text(cal.url),
              ),
            );
          },
          loading: () => const SizedBox(height: 24, child: Center(child: LinearProgressIndicator())),
          error: (_, _) => const SizedBox(),
        ),
        if (t.parentUid != null) ...[
          const SizedBox(height: 16),
          Text('父任务', style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary)),
          const SizedBox(height: 4),
          Card(
            child: ListTile(
              leading: const Icon(Icons.subdirectory_arrow_right),
              title: SelectableText(t.parentUid!),
              subtitle: const Text('UID'),
            ),
          ),
        ],
        // 同步信息
        const SizedBox(height: 16),
        Text('同步信息', style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary)),
        const SizedBox(height: 4),
        Card(
          child: Column(
            children: [
              _kvRow('UID', t.uid),
              if (t.href != null) _kvRow('HREF', t.href!),
              if (t.etag != null) _kvRow('ETag', t.etag!),
              _kvRow('待同步', t.dirty ? '是' : '否'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kvRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(k,
                style: TextStyle(
                    color: Theme.of(context).hintColor, fontSize: 12)),
          ),
          Expanded(
            child: SelectableText(v,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  Widget _timeTile(String label, DateTime? time, DateFormat fmt,
      {bool highlight = false}) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: Icon(Icons.schedule, size: 20,
          color: highlight ? theme.colorScheme.error : null),
      title: Text(label),
      trailing: Text(
        time == null ? '未设置' : fmt.format(time.toLocal()),
        style: TextStyle(
          color: highlight ? theme.colorScheme.error : null,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  // ==================== 编辑模式 ====================

  Widget _buildEditView(AsyncValue calendarsAsync) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _summaryCtrl,
          decoration: const InputDecoration(
            labelText: '标题',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descCtrl,
          decoration: const InputDecoration(
            labelText: '描述',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        // 分类标签编辑
        TextField(
          controller: _categoryCtrl,
          decoration: const InputDecoration(
            labelText: '分类标签（逗号分隔）',
            border: OutlineInputBorder(),
            helperText: '如：工作, 重要, 项目A',
          ),
          onChanged: (v) {
            _categories = v
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String?>(
          initialValue: _calendarUrl,
          decoration: const InputDecoration(
            labelText: '日历',
            border: OutlineInputBorder(),
          ),
          items: calendarsAsync.when(
            data: (list) => list
                .map((c) => DropdownMenuItem<String?>(
                      value: c.url,
                      child: Text(c.displayName),
                    ))
                .toList(),
            loading: () => const [],
            error: (_, _) => const [],
          ),
          onChanged: _isNew ? (v) => setState(() => _calendarUrl = v) : null,
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('开始时间'),
          subtitle: Text(_start == null ? '未设置' : _start!.toLocal().toString()),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _pickDate(_start, (d) => setState(() => _start = d)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('截止时间'),
          subtitle: Text(_due == null ? '未设置' : _due!.toLocal().toString()),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _pickDate(_due, (d) => setState(() => _due = d)),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('状态'),
          trailing: DropdownButton<TaskStatus>(
            value: _status,
            items: TaskStatus.values
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(_statusLabel(s)),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _status = v ?? _status),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('优先级'),
          trailing: DropdownButton<TaskPriority>(
            value: _priority,
            items: TaskPriority.values
                .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(_priorityLabel(p)),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _priority = v ?? _priority),
          ),
        ),
        // 进度滑块
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('完成进度：$_percent%'),
          subtitle: Slider(
            value: _percent.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            label: '$_percent%',
            onChanged: (v) => setState(() {
              _percent = v.round();
              if (_percent >= 100) {
                _status = TaskStatus.completed;
              } else if (_percent > 0 && _status == TaskStatus.needsAction) {
                _status = TaskStatus.inProcess;
              }
            }),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate(DateTime? initial, ValueChanged<DateTime?> onPicked) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now),
    );
    if (time == null) return;
    onPicked(
      DateTime(date.year, date.month, date.day, time.hour, time.minute).toUtc(),
    );
  }

  // ==================== 辅助方法 ====================

  String _statusLabel(TaskStatus s) => switch (s) {
        TaskStatus.needsAction => '未开始',
        TaskStatus.inProcess => '进行中',
        TaskStatus.completed => '已完成',
        TaskStatus.cancelled => '已取消',
      };

  String _priorityLabel(TaskPriority p) => switch (p) {
        TaskPriority.none => '无',
        TaskPriority.high => '高',
        TaskPriority.medium => '中',
        TaskPriority.low => '低',
      };

  IconData _statusIcon(TaskStatus s) => switch (s) {
        TaskStatus.needsAction => Icons.radio_button_unchecked,
        TaskStatus.inProcess => Icons.pending_actions,
        TaskStatus.completed => Icons.check_circle,
        TaskStatus.cancelled => Icons.cancel_outlined,
      };

  Color _statusColor(TaskStatus s, ThemeData theme) => switch (s) {
        TaskStatus.needsAction => theme.colorScheme.outline,
        TaskStatus.inProcess => theme.colorScheme.secondary,
        TaskStatus.completed => theme.colorScheme.primary,
        TaskStatus.cancelled => theme.colorScheme.outline,
      };

  Color _priorityColor(TaskPriority p) => switch (p) {
        TaskPriority.none => Colors.grey,
        TaskPriority.high => Colors.red,
        TaskPriority.medium => Colors.orange,
        TaskPriority.low => Colors.blue,
      };

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      var h = hex.replaceAll('#', '');
      if (h.length == 6) h = 'FF$h';
      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return null;
    }
  }
}

/// 查看模式的标签。
class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Theme.of(context).colorScheme.outline)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: (color ?? Theme.of(context).colorScheme.outline)
              .withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  )),
        ],
      ),
    );
  }
}
