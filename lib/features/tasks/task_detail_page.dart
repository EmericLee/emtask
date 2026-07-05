import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/providers.dart';
import '../../domain/entities/calendar.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_status.dart';
import '../sync/sync_providers.dart';

/// 任务详情 / 编辑页（统一入口）。
///
/// 采用"就地编辑"模式：每个字段点击后直接弹出对应编辑器，
/// 无需切换查看/编辑模式。布局为竖向长方形，紧凑排列。
///
/// 当 [taskId] 为 "new" 时直接进入新建模式（标题字段自动聚焦）。
class TaskDetailPage extends ConsumerStatefulWidget {
  const TaskDetailPage({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  late final bool _isNew = widget.taskId == 'new';
  Task? _loaded;
  bool _loading = true;
  String? _loadError;

  // 新建模式下的临时字段
  String? _newCalendarUrl;

  @override
  void initState() {
    super.initState();
    if (_isNew) {
      _loading = false;
      _initNewCalendar();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _initNewCalendar() async {
    final repo = ref.read(calendarRepositoryProvider);
    final list = await repo.getAll();
    if (mounted && list.isNotEmpty) {
      setState(() => _newCalendarUrl = list.first.url);
    }
  }

  Future<void> _load() async {
    final id = int.tryParse(widget.taskId);
    if (id == null) {
      setState(() {
        _loading = false;
        _loadError = '无效的任务 ID';
      });
      return;
    }
    try {
      final repo = ref.read(taskRepositoryProvider);
      final all = await repo.getAll();
      final t = all.firstWhere(
        (x) => x.localId == id,
        orElse: () => throw StateError('任务不存在'),
      );
      if (!mounted) return;
      setState(() {
        _loaded = t;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _update(Task Function(Task) updater) async {
    final t = _loaded;
    if (t == null) return;
    final next = updater(t).copyWith(
      lastModified: DateTime.now().toUtc(),
      localModifiedAt: DateTime.now().toUtc(),
      dirty: true,
    );
    final repo = ref.read(taskRepositoryProvider);
    await repo.update(next);
    if (mounted) setState(() => _loaded = next);
  }

  Future<void> _create(Task task) async {
    final repo = ref.read(taskRepositoryProvider);
    await repo.create(task);
    if (mounted) context.go('/tasks');
  }

  Future<void> _delete() async {
    final t = _loaded;
    if (t == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确定要删除「${t.summary}」吗？'),
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
    await repo.delete(t.uid);
    if (mounted) context.go('/tasks');
  }

  @override
  Widget build(BuildContext context) {
    final calendarsAsync = ref.watch(calendarListProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isNew) {
              context.go('/tasks');
            } else {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/tasks');
              }
            }
          },
        ),
        title: Text(_isNew ? '新建任务' : '任务详情'),
        actions: [
          if (!_isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
              tooltip: '删除',
            ),
        ],
      ),
      body: _buildBody(calendarsAsync),
    );
  }

  Widget _buildBody(AsyncValue<List<Calendar>> calendarsAsync) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_loadError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      );
    }
    if (_isNew) {
      return _NewTaskForm(
        initialCalendarUrl: _newCalendarUrl,
        calendarsAsync: calendarsAsync,
        onCreate: _create,
      );
    }
    final t = _loaded;
    if (t == null) {
      return const Center(child: Text('任务不存在'));
    }
    return _DetailList(
      task: t,
      calendarsAsync: calendarsAsync,
      onUpdate: _update,
    );
  }
}

// ==================== 详情列表（就地编辑） ====================

class _DetailList extends StatefulWidget {
  const _DetailList({
    required this.task,
    required this.calendarsAsync,
    required this.onUpdate,
  });

  final Task task;
  final AsyncValue<List<Calendar>> calendarsAsync;
  final Future<void> Function(Task Function(Task) updater) onUpdate;

  @override
  State<_DetailList> createState() => _DetailListState();
}

class _DetailListState extends State<_DetailList> {
  // 标题就地编辑状态
  bool _editingTitle = false;
  late final TextEditingController _titleCtrl;
  late final FocusNode _titleFocus;

  static final _fmt = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task.summary);
    _titleFocus = FocusNode();
    _titleFocus.addListener(_onTitleFocusChange);
  }

  @override
  void didUpdateWidget(_DetailList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部任务更新时同步标题控制器（非编辑状态下）
    if (!_editingTitle && widget.task.summary != oldWidget.task.summary) {
      _titleCtrl.text = widget.task.summary;
    }
  }

  void _onTitleFocusChange() {
    if (!_titleFocus.hasFocus && _editingTitle) {
      _commitTitle();
    }
  }

  Future<void> _commitTitle() async {
    final v = _titleCtrl.text.trim();
    if (v.isEmpty) {
      // 标题不允许为空，恢复原值
      _titleCtrl.text = widget.task.summary;
      if (mounted) setState(() => _editingTitle = false);
      return;
    }
    if (v != widget.task.summary) {
      await widget.onUpdate((t) => t.copyWith(summary: v));
    }
    if (mounted) setState(() => _editingTitle = false);
  }

  @override
  void dispose() {
    _titleFocus.removeListener(_onTitleFocusChange);
    _titleFocus.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _setStatus(TaskStatus s) async {
    final t = widget.task;
    final completed = s == TaskStatus.completed
        ? (t.completed ?? DateTime.now().toUtc())
        : null;
    final percent = s == TaskStatus.completed
        ? 100
        : (s == TaskStatus.needsAction ? 0 : t.percent);
    await widget.onUpdate((x) => x.copyWith(
          status: s,
          completed: completed,
          percent: percent,
        ));
  }

  Future<void> _setPriority(TaskPriority p) async {
    await widget.onUpdate((t) => t.copyWith(priority: p));
  }

  Future<void> _setPercent(int p) async {
    TaskStatus status = widget.task.status;
    DateTime? completed = widget.task.completed;
    if (p >= 100) {
      status = TaskStatus.completed;
      completed = completed ?? DateTime.now().toUtc();
    } else if (p > 0 && status == TaskStatus.needsAction) {
      status = TaskStatus.inProcess;
      completed = null;
    } else if (p == 0 && status == TaskStatus.completed) {
      status = TaskStatus.needsAction;
      completed = null;
    }
    await widget.onUpdate((t) => t.copyWith(
          percent: p,
          status: status,
          completed: completed,
        ));
  }

  Future<void> _editDescription() async {
    final ctrl = TextEditingController(text: widget.task.description);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑描述'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 8,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null) return;
    await widget.onUpdate((t) => t.copyWith(description: result));
  }

  Future<void> _editCategories() async {
    final ctrl =
        TextEditingController(text: widget.task.categories.join(', '));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑标签'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '标签（用逗号分隔）',
            helperText: '如：工作, 重要, 项目A',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null) return;
    final list = result
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    await widget.onUpdate((t) => t.copyWith(categories: list));
  }

  Future<void> _pickDateTime(
    String title,
    DateTime? initial,
    ValueChanged<DateTime?> onSaved,
  ) async {
    final now = DateTime.now();
    final cleared = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_calendar),
              title: Text(initial == null
                  ? '选择日期时间'
                  : _fmt.format(initial.toLocal())),
              onTap: () => Navigator.pop(ctx, false),
            ),
            if (initial != null)
              ListTile(
                leading: const Icon(Icons.clear),
                title: const Text('清除时间'),
                onTap: () => Navigator.pop(ctx, true),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
        ],
      ),
    );
    if (cleared == null) return;
    if (cleared) {
      onSaved(null);
      return;
    }
    if (!mounted) return;
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now),
    );
    if (time == null) return;
    onSaved(
      DateTime(date.year, date.month, date.day, time.hour, time.minute)
          .toUtc(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final task = widget.task;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        // 标题（就地 TextField）
        if (_editingTitle)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _titleCtrl,
              focusNode: _titleFocus,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _commitTitle(),
              decoration: InputDecoration(
                labelText: '标题',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check, size: 18),
                  onPressed: _commitTitle,
                ),
              ),
            ),
          )
        else
          _EditTile(
            icon: Icons.title,
            label: '标题',
            value: task.summary,
            style: theme.textTheme.titleMedium?.copyWith(
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              color: task.isCompleted ? scheme.outline : null,
              fontWeight: FontWeight.w600,
            ),
            trailing: const Icon(Icons.edit_outlined, size: 18),
            onTap: () {
              _titleCtrl.text = task.summary;
              setState(() => _editingTitle = true);
            },
          ),
        const _Divider(),
        // 状态：PopupMenuButton 就地下拉
        _EditTile(
          icon: _statusIcon(task.status),
          iconColor: _statusColor(task.status, scheme),
          label: '状态',
          value: _statusLabel(task.status),
          trailing: _StatusPopup(
            current: task.status,
            onSelected: _setStatus,
          ),
        ),
        // 优先级：PopupMenuButton 就地下拉
        _EditTile(
          icon: Icons.flag_outlined,
          iconColor: _priorityColor(task.priority),
          label: '优先级',
          value: _priorityLabel(task.priority),
          trailing: _PriorityPopup(
            current: task.priority,
            onSelected: _setPriority,
          ),
        ),
        // 进度：内联 Slider（点击展开）
        _PercentEditor(
          task: task,
          onUpdate: _setPercent,
        ),
        const _Divider(),
        // 时间信息：开始 / 截止 / 完成
        _EditTile(
          icon: Icons.play_arrow_outlined,
          label: '开始时间',
          value: task.start == null
              ? '未设置'
              : _fmt.format(task.start!.toLocal()),
          valueColor: scheme.onSurface,
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: () => _pickDateTime(
            '开始时间',
            task.start,
            (v) => widget.onUpdate((t) => t.copyWith(start: v)),
          ),
        ),
        _EditTile(
          icon: Icons.event_outlined,
          label: '截止时间',
          value: task.due == null
              ? '未设置'
              : _fmt.format(task.due!.toLocal()),
          valueColor: task.isOverdue ? scheme.error : scheme.onSurface,
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: () => _pickDateTime(
            '截止时间',
            task.due,
            (v) => widget.onUpdate((t) => t.copyWith(due: v)),
          ),
        ),
        _EditTile(
          icon: Icons.check_circle_outline,
          label: '完成时间',
          value: task.completed == null
              ? '未完成'
              : _fmt.format(task.completed!.toLocal()),
          valueColor: scheme.outline,
          onTap: task.completed != null
              ? () =>
                  widget.onUpdate((t) => t.copyWith(completed: null))
              : null,
        ),
        const _Divider(),
        // 描述
        _EditTile(
          icon: Icons.notes,
          label: '描述',
          value: task.description.trim().isEmpty
              ? '点击添加描述'
              : task.description,
          valueColor: task.description.trim().isEmpty
              ? scheme.outline
              : scheme.onSurface,
          maxLines: 4,
          trailing: const Icon(Icons.edit_outlined, size: 18),
          onTap: _editDescription,
        ),
        const _Divider(),
        // 分类标签
        _EditTile(
          icon: Icons.label_outline,
          label: '标签',
          value: task.categories.isEmpty
              ? '点击添加标签'
              : task.categories.join('，'),
          valueColor: task.categories.isEmpty
              ? scheme.outline
              : scheme.onSurface,
          trailing: const Icon(Icons.edit_outlined, size: 18),
          onTap: _editCategories,
        ),
        const _Divider(),
        // 所属日历
        _CalendarTile(
          task: task,
          calendarsAsync: widget.calendarsAsync,
        ),
        // 父任务
        if (task.parentUid != null && task.parentUid!.isNotEmpty) ...[
          const _Divider(),
          _EditTile(
            icon: Icons.subdirectory_arrow_right,
            label: '父任务',
            value: task.parentUid!,
            valueColor: scheme.outline,
            mono: true,
          ),
        ],
        const _Divider(),
        // 同步信息（折叠区）
        _SyncInfoTile(task: task),
      ],
    );
  }

  // ---------- 辅助方法 ----------

  static String _statusLabel(TaskStatus s) => switch (s) {
        TaskStatus.needsAction => '未开始',
        TaskStatus.inProcess => '进行中',
        TaskStatus.completed => '已完成',
        TaskStatus.cancelled => '已取消',
      };

  static String _priorityLabel(TaskPriority p) => switch (p) {
        TaskPriority.none => '无',
        TaskPriority.high => '高',
        TaskPriority.medium => '中',
        TaskPriority.low => '低',
      };

  static IconData _statusIcon(TaskStatus s) => switch (s) {
        TaskStatus.needsAction => Icons.radio_button_unchecked,
        TaskStatus.inProcess => Icons.pending_actions,
        TaskStatus.completed => Icons.check_circle,
        TaskStatus.cancelled => Icons.cancel_outlined,
      };

  static Color _statusColor(TaskStatus s, ColorScheme scheme) => switch (s) {
        TaskStatus.needsAction => scheme.outline,
        TaskStatus.inProcess => scheme.secondary,
        TaskStatus.completed => scheme.primary,
        TaskStatus.cancelled => scheme.outline,
      };

  static Color _priorityColor(TaskPriority p) => switch (p) {
        TaskPriority.none => Colors.grey,
        TaskPriority.high => Colors.red,
        TaskPriority.medium => Colors.orange,
        TaskPriority.low => Colors.blue,
      };
}

/// 状态就地下拉菜单。
class _StatusPopup extends StatelessWidget {
  const _StatusPopup({required this.current, required this.onSelected});

  final TaskStatus current;
  final ValueChanged<TaskStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<TaskStatus>(
      icon: const Icon(Icons.unfold_more, size: 18),
      tooltip: '选择状态',
      onSelected: onSelected,
      itemBuilder: (ctx) => TaskStatus.values.map((s) {
        return PopupMenuItem<TaskStatus>(
          value: s,
          child: Row(
            children: [
              Icon(_statusIcon(s),
                  size: 18,
                  color: _statusColor(s, Theme.of(ctx).colorScheme)),
              const SizedBox(width: 8),
              Expanded(child: Text(_statusLabel(s))),
              if (s == current)
                Icon(Icons.check,
                    size: 16, color: scheme.primary),
            ],
          ),
        );
      }).toList(),
    );
  }

  static String _statusLabel(TaskStatus s) => switch (s) {
        TaskStatus.needsAction => '未开始',
        TaskStatus.inProcess => '进行中',
        TaskStatus.completed => '已完成',
        TaskStatus.cancelled => '已取消',
      };

  static IconData _statusIcon(TaskStatus s) => switch (s) {
        TaskStatus.needsAction => Icons.radio_button_unchecked,
        TaskStatus.inProcess => Icons.pending_actions,
        TaskStatus.completed => Icons.check_circle,
        TaskStatus.cancelled => Icons.cancel_outlined,
      };

  static Color _statusColor(TaskStatus s, ColorScheme scheme) => switch (s) {
        TaskStatus.needsAction => scheme.outline,
        TaskStatus.inProcess => scheme.secondary,
        TaskStatus.completed => scheme.primary,
        TaskStatus.cancelled => scheme.outline,
      };
}

/// 优先级就地下拉菜单。
class _PriorityPopup extends StatelessWidget {
  const _PriorityPopup({required this.current, required this.onSelected});

  final TaskPriority current;
  final ValueChanged<TaskPriority> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<TaskPriority>(
      icon: const Icon(Icons.unfold_more, size: 18),
      tooltip: '选择优先级',
      onSelected: onSelected,
      itemBuilder: (ctx) => TaskPriority.values.map((p) {
        return PopupMenuItem<TaskPriority>(
          value: p,
          child: Row(
            children: [
              Icon(Icons.flag_outlined, size: 18, color: _priorityColor(p)),
              const SizedBox(width: 8),
              Expanded(child: Text(_priorityLabel(p))),
              if (p == current)
                Icon(Icons.check, size: 16, color: scheme.primary),
            ],
          ),
        );
      }).toList(),
    );
  }

  static String _priorityLabel(TaskPriority p) => switch (p) {
        TaskPriority.none => '无',
        TaskPriority.high => '高',
        TaskPriority.medium => '中',
        TaskPriority.low => '低',
      };

  static Color _priorityColor(TaskPriority p) => switch (p) {
        TaskPriority.none => Colors.grey,
        TaskPriority.high => Colors.red,
        TaskPriority.medium => Colors.orange,
        TaskPriority.low => Colors.blue,
      };
}

/// 进度就地编辑：点击行展开内联 Slider。
class _PercentEditor extends StatefulWidget {
  const _PercentEditor({required this.task, required this.onUpdate});

  final Task task;
  final ValueChanged<int> onUpdate;

  @override
  State<_PercentEditor> createState() => _PercentEditorState();
}

class _PercentEditorState extends State<_PercentEditor> {
  bool _expanded = false;
  int? _draggingValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = _draggingValue ?? widget.task.percent;
    return Column(
      children: [
        _EditTile(
          icon: Icons.percent_outlined,
          label: '完成进度',
          value: '$display%',
          trailing: SizedBox(
            width: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: display / 100,
                minHeight: 6,
              ),
            ),
          ),
          onTap: () => setState(() {
            _expanded = !_expanded;
            _draggingValue = null;
          }),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Text('0%', style: theme.textTheme.labelSmall),
                Expanded(
                  child: Slider(
                    value: display.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '$display%',
                    onChanged: (v) =>
                        setState(() => _draggingValue = v.round()),
                    onChangeEnd: (v) {
                      widget.onUpdate(v.round());
                      if (mounted) setState(() => _draggingValue = null);
                    },
                  ),
                ),
                Text('100%', style: theme.textTheme.labelSmall),
                IconButton(
                  tooltip: '收起',
                  icon: const Icon(Icons.expand_less, size: 18),
                  onPressed: () =>
                      setState(() {_expanded = false; _draggingValue = null;}),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ==================== 可编辑字段行 ====================

class _EditTile extends StatelessWidget {
  const _EditTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.iconColor,
    this.valueColor,
    this.trailing,
    this.style,
    this.maxLines = 1,
    this.mono = false,
  });

  final IconData icon;
  final Color? iconColor;
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;
  final TextStyle? style;
  final int maxLines;
  final bool mono;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: iconColor ?? scheme.outline),
            const SizedBox(width: 10),
            SizedBox(
              width: 72,
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.outline,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: style ??
                    theme.textTheme.bodyMedium?.copyWith(
                      color: valueColor,
                      fontFamily: mono ? 'monospace' : null,
                    ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _CalendarTile extends StatelessWidget {
  const _CalendarTile({required this.task, required this.calendarsAsync});

  final Task task;
  final AsyncValue<List<Calendar>> calendarsAsync;

  @override
  Widget build(BuildContext context) {
    return calendarsAsync.when(
      data: (list) {
        final cal = list.firstWhere(
          (c) => c.url == task.calendarUrl,
          orElse: () => Calendar(
            localId: 0,
            url: task.calendarUrl,
            displayName: task.calendarUrl,
            color: '',
            supportsTasks: true,
            supportsEvents: false,
            owner: '',
            syncEnabled: true,
          ),
        );
        return _EditTile(
          icon: Icons.calendar_today_outlined,
          iconColor: _parseColor(cal.color),
          label: '所属清单',
          value: cal.displayName,
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: LinearProgressIndicator()),
      ),
      error: (_, _) => _EditTile(
        icon: Icons.calendar_today_outlined,
        label: '所属清单',
        value: task.calendarUrl,
      ),
    );
  }

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

/// 同步信息折叠区。
class _SyncInfoTile extends StatefulWidget {
  const _SyncInfoTile({required this.task});

  final Task task;

  @override
  State<_SyncInfoTile> createState() => _SyncInfoTileState();
}

class _SyncInfoTileState extends State<_SyncInfoTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = widget.task;
    final fmt = DateFormat('yyyy-MM-dd HH:mm:ss');
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.sync_outlined, size: 18, color: scheme.outline),
                const SizedBox(width: 10),
                const SizedBox(width: 72, child: Text('同步信息')),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.dirty ? '待同步' : '已同步',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: t.dirty ? scheme.error : scheme.outline,
                    ),
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: scheme.outline,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _kv('UID', t.uid, scheme),
                  if (t.href != null) _kv('HREF', t.href!, scheme),
                  if (t.etag != null) _kv('ETag', t.etag!, scheme),
                  if (t.created != null)
                    _kv('创建时间', fmt.format(t.created!.toLocal()), scheme),
                  if (t.lastModified != null)
                    _kv('最后修改', fmt.format(t.lastModified!.toLocal()),
                        scheme),
                  _kv('待同步', t.dirty ? '是' : '否', scheme),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _kv(String k, String v, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(k,
                style: TextStyle(
                    color: scheme.outline, fontSize: 12)),
          ),
          Expanded(
            child: SelectableText(v,
                style: const TextStyle(
                    fontSize: 12, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
      ),
    );
  }
}

// ==================== 新建任务表单 ====================

class _NewTaskForm extends StatefulWidget {
  const _NewTaskForm({
    required this.initialCalendarUrl,
    required this.calendarsAsync,
    required this.onCreate,
  });

  final String? initialCalendarUrl;
  final AsyncValue<List<Calendar>> calendarsAsync;
  final Future<void> Function(Task task) onCreate;

  @override
  State<_NewTaskForm> createState() => _NewTaskFormState();
}

class _NewTaskFormState extends State<_NewTaskForm> {
  final _summaryCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  DateTime? _start;
  DateTime? _due;
  TaskStatus _status = TaskStatus.needsAction;
  TaskPriority _priority = TaskPriority.none;
  final _percent = 0;
  String? _calendarUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _calendarUrl = widget.initialCalendarUrl;
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
    if (_calendarUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在设置中配置 CalDAV 账户')),
      );
      return;
    }
    setState(() => _saving = true);
    final categories = _categoryCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final completed = _status == TaskStatus.completed
        ? DateTime.now().toUtc()
        : null;
    final task = Task.create(
      calendarUrl: _calendarUrl!,
      summary: _summaryCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      start: _start,
      due: _due,
      status: _status,
      priority: _priority,
      categories: categories,
    ).copyWith(percent: _percent, completed: completed);
    await widget.onCreate(task);
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickDateTime(ValueChanged<DateTime?> onPicked) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) return;
    onPicked(
      DateTime(date.year, date.month, date.day, time.hour, time.minute)
          .toUtc(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        // 日历选择
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: DropdownButtonFormField<String?>(
            value: _calendarUrl,
            decoration: const InputDecoration(
              labelText: '所属清单',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: widget.calendarsAsync.when(
              data: (list) => list
                  .map((c) => DropdownMenuItem<String?>(
                        value: c.url,
                        child: Text(c.displayName),
                      ))
                  .toList(),
              loading: () => const [],
              error: (_, _) => const [],
            ),
            onChanged: (v) => setState(() => _calendarUrl = v),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _summaryCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '标题',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descCtrl,
          decoration: const InputDecoration(
            labelText: '描述',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          maxLines: 4,
        ),
        const SizedBox(height: 8),
        _EditTile(
          icon: _statusIcon(_status),
          iconColor: _statusColor(_status, scheme),
          label: '状态',
          value: _statusLabel(_status),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: () async {
            final s = await showDialog<TaskStatus>(
              context: context,
              builder: (ctx) => SimpleDialog(
                title: const Text('选择状态'),
                children: TaskStatus.values.map((s) {
                  return SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, s),
                    child: Row(children: [
                      Icon(_statusIcon(s),
                          color: _statusColor(s, Theme.of(ctx).colorScheme)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_statusLabel(s))),
                      if (s == _status) const Icon(Icons.check, size: 18),
                    ]),
                  );
                }).toList(),
              ),
            );
            if (s != null) setState(() => _status = s);
          },
        ),
        _EditTile(
          icon: Icons.flag_outlined,
          iconColor: _priorityColor(_priority),
          label: '优先级',
          value: _priorityLabel(_priority),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: () async {
            final p = await showDialog<TaskPriority>(
              context: context,
              builder: (ctx) => SimpleDialog(
                title: const Text('选择优先级'),
                children: TaskPriority.values.map((p) {
                  return SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, p),
                    child: Row(children: [
                      Icon(Icons.flag_outlined, color: _priorityColor(p)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_priorityLabel(p))),
                      if (p == _priority) const Icon(Icons.check, size: 18),
                    ]),
                  );
                }).toList(),
              ),
            );
            if (p != null) setState(() => _priority = p);
          },
        ),
        _EditTile(
          icon: Icons.play_arrow_outlined,
          label: '开始时间',
          value: _start == null ? '未设置' : fmt.format(_start!.toLocal()),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: () => _pickDateTime((v) => setState(() => _start = v)),
        ),
        _EditTile(
          icon: Icons.event_outlined,
          label: '截止时间',
          value: _due == null ? '未设置' : fmt.format(_due!.toLocal()),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: () => _pickDateTime((v) => setState(() => _due = v)),
        ),
        const _Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextField(
            controller: _categoryCtrl,
            decoration: const InputDecoration(
              labelText: '标签（用逗号分隔）',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: const Text('创建任务'),
          ),
        ),
      ],
    );
  }

  // ---------- 辅助 ----------

  static String _statusLabel(TaskStatus s) => switch (s) {
        TaskStatus.needsAction => '未开始',
        TaskStatus.inProcess => '进行中',
        TaskStatus.completed => '已完成',
        TaskStatus.cancelled => '已取消',
      };

  static String _priorityLabel(TaskPriority p) => switch (p) {
        TaskPriority.none => '无',
        TaskPriority.high => '高',
        TaskPriority.medium => '中',
        TaskPriority.low => '低',
      };

  static IconData _statusIcon(TaskStatus s) => switch (s) {
        TaskStatus.needsAction => Icons.radio_button_unchecked,
        TaskStatus.inProcess => Icons.pending_actions,
        TaskStatus.completed => Icons.check_circle,
        TaskStatus.cancelled => Icons.cancel_outlined,
      };

  static Color _statusColor(TaskStatus s, ColorScheme scheme) => switch (s) {
        TaskStatus.needsAction => scheme.outline,
        TaskStatus.inProcess => scheme.secondary,
        TaskStatus.completed => scheme.primary,
        TaskStatus.cancelled => scheme.outline,
      };

  static Color _priorityColor(TaskPriority p) => switch (p) {
        TaskPriority.none => Colors.grey,
        TaskPriority.high => Colors.red,
        TaskPriority.medium => Colors.orange,
        TaskPriority.low => Colors.blue,
      };
}


