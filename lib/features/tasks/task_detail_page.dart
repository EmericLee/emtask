import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/providers.dart';
import '../../domain/entities/calendar.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_status.dart';
import '../sync/sync_providers.dart';
import 'task_providers.dart';

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
  // 所有任务已用过的标签集合（供标签编辑器检索）
  List<String> _allTags = const [];
  // 一次性自动编辑标题信号
  bool _autoEditTitle = false;

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
    // 读取并消费一次性自动编辑信号
    final autoEdit = ref.read(autoEditTitleProvider);
    if (autoEdit) {
      ref.read(autoEditTitleProvider.notifier).state = false;
    }
    final id = int.tryParse(widget.taskId);
    if (id == null) {
      setState(() {
        _loading = false;
        _loadError = '无效的任务 ID';
      });
      return;
    }
    setState(() => _autoEditTitle = autoEdit);
    try {
      final repo = ref.read(taskRepositoryProvider);
      final all = await repo.getAll();
      final t = all.firstWhere(
        (x) => x.localId == id,
        orElse: () => throw StateError('任务不存在'),
      );
      // 汇总所有任务的标签，供标签编辑器检索
      final tags = <String>{};
      for (final x in all) {
        tags.addAll(x.categories);
      }
      if (!mounted) return;
      setState(() {
        _loaded = t;
        _allTags = tags.toList()..sort();
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

  /// 外部任务列表变化时同步刷新（不显示 loading，避免闪烁）。
  Future<void> _refreshFromExternal() async {
    final current = _loaded;
    if (current == null || _loading) return;
    try {
      final repo = ref.read(taskRepositoryProvider);
      final all = await repo.getAll();
      final t = all.firstWhere(
        (x) => x.localId == int.tryParse(widget.taskId),
        orElse: () => throw StateError('任务不存在'),
      );
      if (!mounted) return;
      if (t != current) {
        final tags = <String>{};
        for (final x in all) {
          tags.addAll(x.categories);
        }
        setState(() {
          _loaded = t;
          _allTags = tags.toList()..sort();
        });
      }
    } catch (_) {
      // 静默忽略：外部刷新失败不影响当前显示
    }
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
    // 监听任务列表变化，外部修改后同步刷新（如任务条内联编辑标题）
    ref.listen(taskListProvider, (prev, next) {
      if (_isNew || _loaded == null) return;
      next.whenData((_) => _refreshFromExternal());
    });
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
      allTags: _allTags,
      onUpdate: _update,
      autoEditTitle: _autoEditTitle,
    );
  }
}

/// 任务详情面板（用于宽屏侧栏嵌入）。
///
/// 与 [TaskDetailPage] 功能一致，但以关闭按钮替代返回按钮，
/// 删除任务后通过 [onClose] 回调通知父组件清除选中状态。
class TaskDetailPanel extends ConsumerStatefulWidget {
  const TaskDetailPanel({
    super.key,
    required this.taskId,
    this.onClose,
  });

  final int taskId;
  final VoidCallback? onClose;

  @override
  ConsumerState<TaskDetailPanel> createState() => _TaskDetailPanelState();
}

class _TaskDetailPanelState extends ConsumerState<TaskDetailPanel> {
  Task? _loaded;
  bool _loading = true;
  String? _loadError;
  List<String> _allTags = const [];
  bool _autoEditTitle = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant TaskDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId) {
      _load();
    }
  }

  Future<void> _load() async {
    // 读取并消费一次性自动编辑信号
    final autoEdit = ref.read(autoEditTitleProvider);
    if (autoEdit) {
      ref.read(autoEditTitleProvider.notifier).state = false;
    }
    setState(() {
      _loading = true;
      _autoEditTitle = autoEdit;
    });
    try {
      final repo = ref.read(taskRepositoryProvider);
      final all = await repo.getAll();
      final t = all.firstWhere(
        (x) => x.localId == widget.taskId,
        orElse: () => throw StateError('任务不存在'),
      );
      final tags = <String>{};
      for (final x in all) {
        tags.addAll(x.categories);
      }
      if (!mounted) return;
      setState(() {
        _loaded = t;
        _allTags = tags.toList()..sort();
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

  /// 外部任务列表变化时同步刷新（不显示 loading，避免闪烁）。
  Future<void> _refreshFromExternal() async {
    final current = _loaded;
    if (current == null || _loading) return;
    try {
      final repo = ref.read(taskRepositoryProvider);
      final all = await repo.getAll();
      final t = all.firstWhere(
        (x) => x.localId == widget.taskId,
        orElse: () => throw StateError('任务不存在'),
      );
      if (!mounted) return;
      if (t != current) {
        final tags = <String>{};
        for (final x in all) {
          tags.addAll(x.categories);
        }
        setState(() {
          _loaded = t;
          _allTags = tags.toList()..sort();
        });
      }
    } catch (_) {
      // 静默忽略：外部刷新失败不影响当前显示
    }
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
    if (mounted) widget.onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    final calendarsAsync = ref.watch(calendarListProvider);
    // 监听任务列表变化，外部修改后同步刷新（如任务条内联编辑标题）
    ref.listen(taskListProvider, (prev, next) {
      if (_loaded == null) return;
      next.whenData((_) => _refreshFromExternal());
    });
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onClose,
          tooltip: '关闭',
        ),
        title: const Text('任务详情'),
        actions: [
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
    final t = _loaded;
    if (t == null) {
      return const Center(child: Text('任务不存在'));
    }
    return _DetailList(
      task: t,
      calendarsAsync: calendarsAsync,
      allTags: _allTags,
      onUpdate: _update,
      autoEditTitle: _autoEditTitle,
    );
  }
}

// ==================== 详情列表（就地编辑） ====================

class _DetailList extends StatefulWidget {
  const _DetailList({
    required this.task,
    required this.calendarsAsync,
    required this.allTags,
    required this.onUpdate,
    this.autoEditTitle = false,
  });

  final Task task;
  final AsyncValue<List<Calendar>> calendarsAsync;
  final List<String> allTags;
  final Future<void> Function(Task Function(Task) updater) onUpdate;

  /// 是否在首次构建时自动进入标题编辑状态（新建任务场景）。
  final bool autoEditTitle;

  @override
  State<_DetailList> createState() => _DetailListState();
}

class _DetailListState extends State<_DetailList> {
  // 标题就地编辑状态
  bool _editingTitle = false;
  late final TextEditingController _titleCtrl;
  late final FocusNode _titleFocus;

  @override
  void initState() {
    super.initState();
    _editingTitle = widget.autoEditTitle;
    _titleCtrl = TextEditingController(text: widget.task.summary);
    _titleFocus = FocusNode();
    _titleFocus.addListener(_onTitleFocusChange);
    // 自动编辑时请求焦点
    if (widget.autoEditTitle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _titleFocus.requestFocus();
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final task = widget.task;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        // 标题（就地 TextField，单行，回车保存）
        if (_editingTitle)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _titleCtrl,
              focusNode: _titleFocus,
              autofocus: true,
              maxLines: 1,
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
            maxLines: null,
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
        // 描述：点击内联展开多行编辑
        _DescriptionField(
          description: task.description,
          onChanged: (v) => widget.onUpdate((t) => t.copyWith(description: v)),
        ),
        const _Divider(),
        // 时间信息：开始 / 截止 / 完成
        _DateTimeField(
          icon: Icons.play_arrow_outlined,
          label: '开始时间',
          value: task.start,
          onSaved: (v) => widget.onUpdate((t) => t.copyWith(start: v)),
        ),
        _DateTimeField(
          icon: Icons.event_outlined,
          label: '截止时间',
          value: task.due,
          valueColor: task.isOverdue ? scheme.error : null,
          onSaved: (v) => widget.onUpdate((t) => t.copyWith(due: v)),
        ),
        _DateTimeField(
          icon: Icons.check_circle_outline,
          label: '完成时间',
          value: task.completed,
          valueColor: scheme.outline,
          onSaved: (v) => widget.onUpdate((t) => t.copyWith(completed: v)),
        ),
        const _Divider(),
        // 状态：下拉选择控件
        _DropdownField<TaskStatus>(
          icon: _statusIcon(task.status),
          iconColor: _statusColor(task.status, scheme),
          label: '状态',
          value: task.status,
          onChanged: _setStatus,
          options: TaskStatus.values
              .map((s) => _DropdownOption(
                    value: s,
                    label: _statusLabel(s),
                    icon: _statusIcon(s),
                    color: _statusColor(s, scheme),
                  ))
              .toList(),
        ),
        // 进度：内联 Slider（点击展开）
        _PercentEditor(
          task: task,
          onUpdate: _setPercent,
        ),
        // 优先级：下拉选择控件
        _DropdownField<TaskPriority>(
          icon: Icons.flag_outlined,
          iconColor: _priorityColor(task.priority),
          label: '优先级',
          value: task.priority,
          onChanged: _setPriority,
          options: TaskPriority.values
              .map((p) => _DropdownOption(
                    value: p,
                    label: _priorityLabel(p),
                    icon: Icons.flag_outlined,
                    color: _priorityColor(p),
                  ))
              .toList(),
        ),
        const _Divider(),
        // 标签：内联 InputChip 编辑
        _TagEditor(
          tags: task.categories,
          allTags: widget.allTags,
          onChanged: (list) =>
              widget.onUpdate((t) => t.copyWith(categories: list)),
        ),
        const _Divider(),
        // 所属日历：下拉选择可切换日历
        widget.calendarsAsync.when(
          data: (list) {
            final current = list.firstWhere(
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
            return _DropdownField<String>(
              icon: Icons.calendar_today_outlined,
              iconColor: _parseCalendarColor(current.color),
              label: '所属清单',
              value: task.calendarUrl,
              onChanged: (url) =>
                  widget.onUpdate((t) => t.copyWith(calendarUrl: url)),
              options: list
                  .where((c) => c.supportsTasks)
                  .map((c) => _DropdownOption(
                        value: c.url,
                        label: c.displayName,
                        icon: Icons.calendar_today_outlined,
                        color: _parseCalendarColor(c.color),
                      ))
                  .toList(),
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
        TaskStatus.needsAction => '需要操作',
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

/// 日期时间字段：点击就地弹出紧凑选择面板（含清除按钮）。
///
/// 默认仅显示日期；开启"日期字段显示时间"配置后可选择时分。
/// 面板定位到触发行下方；空间不足时向上弹出。
class _DateTimeField extends ConsumerStatefulWidget {
  const _DateTimeField({
    required this.icon,
    required this.label,
    required this.value,
    required this.onSaved,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final DateTime? value;
  final Color? valueColor;
  final ValueChanged<DateTime?> onSaved;

  @override
  ConsumerState<_DateTimeField> createState() => _DateTimeFieldState();
}

class _DateTimeFieldState extends ConsumerState<_DateTimeField> {
  final GlobalKey _tileKey = GlobalKey();
  static final _fmtDate = DateFormat('yyyy-MM-dd');
  static final _fmtDateTime = DateFormat('yyyy-MM-dd HH:mm');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showTime = ref.watch(showTimeInDateFieldProvider);
    final fmt = showTime ? _fmtDateTime : _fmtDate;
    final value = widget.value == null
        ? '未设置'
        : fmt.format(widget.value!.toLocal());
    return Padding(
      key: _tileKey,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(widget.icon, size: 18, color: scheme.outline),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(widget.label,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: scheme.outline)),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: InkWell(
              onTap: _openPopover,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: widget.valueColor ?? scheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (widget.value != null)
                      GestureDetector(
                        onTap: () => widget.onSaved(null),
                        child: Icon(Icons.clear,
                            size: 16, color: scheme.outline),
                      )
                    else
                      Icon(Icons.chevron_right,
                          size: 18, color: scheme.outline),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openPopover() {
    final ctx = _tileKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox;
    final size = box.size;
    final topLeft = box.localToGlobal(Offset.zero);
    final overlay = Overlay.of(ctx);
    final media = MediaQuery.of(ctx);
    final showTime = ref.read(showTimeInDateFieldProvider);

    const panelWidth = 296.0;
    final panelHeight = showTime ? 420.0 : 380.0;
    // 下方空间不足则向上弹出
    final showBelow =
        topLeft.dy + size.height + panelHeight + 16 < media.size.height;
    final top = showBelow
        ? math.min(topLeft.dy + size.height + 4,
            media.size.height - panelHeight - 8)
        : math.max(8.0, topLeft.dy - panelHeight - 4);
    final left = (topLeft.dx)
        .clamp(8.0, math.max(8.0, media.size.width - panelWidth - 8))
        .toDouble();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _DateTimePopover(
        left: left,
        top: top,
        panelWidth: panelWidth,
        initial: widget.value ?? DateTime.now(),
        showTime: showTime,
        onCancel: () => entry.remove(),
        onClear: () {
          entry.remove();
          widget.onSaved(null);
        },
        onConfirm: (v) {
          entry.remove();
          widget.onSaved(v);
        },
      ),
    );
    overlay.insert(entry);
  }
}

/// 紧凑日期时间选择面板（OverlayEntry 内容）。
class _DateTimePopover extends StatefulWidget {
  const _DateTimePopover({
    required this.left,
    required this.top,
    required this.panelWidth,
    required this.initial,
    required this.showTime,
    required this.onCancel,
    required this.onClear,
    required this.onConfirm,
  });

  final double left;
  final double top;
  final double panelWidth;
  final DateTime initial;
  final bool showTime;
  final VoidCallback onCancel;
  final VoidCallback onClear;
  final ValueChanged<DateTime> onConfirm;

  @override
  State<_DateTimePopover> createState() => _DateTimePopoverState();
}

class _DateTimePopoverState extends State<_DateTimePopover> {
  late DateTime _date;
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _date = DateTime(widget.initial.year, widget.initial.month, widget.initial.day);
    _hour = widget.initial.hour;
    _minute = widget.initial.minute;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Stack(
      children: [
        // 遮罩：点击空白处关闭
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onCancel,
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: widget.left,
          top: widget.top,
          child: TapRegion(
            onTapOutside: (_) => widget.onCancel(),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: scheme.surface,
              surfaceTintColor: scheme.surfaceTint,
              child: SizedBox(
                width: widget.panelWidth,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 320,
                        child: CalendarDatePicker(
                          initialDate: _date,
                          firstDate: DateTime(widget.initial.year - 5),
                          lastDate: DateTime(widget.initial.year + 5),
                          onDateChanged: (d) => setState(() => _date = d),
                        ),
                      ),
                      const Divider(height: 1),
                      // 时间行（仅 showTime 时显示）
                      if (widget.showTime)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
                          child: Row(
                            children: [
                              Text('时间',
                                  style: theme.textTheme.labelMedium
                                      ?.copyWith(color: scheme.outline)),
                              const SizedBox(width: 8),
                              _TimeSpinner(
                                value: _hour,
                                maxValue: 23,
                                onChanged: (v) => setState(() => _hour = v),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Text(':'),
                              ),
                              _TimeSpinner(
                                value: _minute,
                                maxValue: 59,
                                onChanged: (v) => setState(() => _minute = v),
                              ),
                            ],
                          ),
                        ),
                      // 按钮行：清除 / 取消 / 确定
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                                onPressed: widget.onClear,
                                child: const Text('清除')),
                            TextButton(
                                onPressed: widget.onCancel,
                                child: const Text('取消')),
                            FilledButton(
                              onPressed: () => widget.onConfirm(
                                DateTime(_date.year, _date.month, _date.day,
                                        _hour, _minute)
                                    .toUtc(),
                              ),
                              child: const Text('确定'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 紧凑时间数字 Spinner（点击上下箭头调整，循环）。
class _TimeSpinner extends StatelessWidget {
  const _TimeSpinner({
    required this.value,
    required this.maxValue,
    required this.onChanged,
  });

  final int value;
  final int maxValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => onChanged((value + 1) % (maxValue + 1)),
            child: Icon(Icons.arrow_drop_up, size: 16, color: scheme.outline),
          ),
          Text(
            value.toString().padLeft(2, '0'),
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
              fontSize: 14,
            ),
          ),
          InkWell(
            onTap: () =>
                onChanged((value - 1 + maxValue + 1) % (maxValue + 1)),
            child:
                Icon(Icons.arrow_drop_down, size: 16, color: scheme.outline),
          ),
        ],
      ),
    );
  }
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
  bool _editing = false;
  int _draggingValue = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final display = _editing ? _draggingValue : widget.task.percent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.percent_outlined, size: 18, color: scheme.outline),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text('完成进度',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: scheme.outline)),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: _editing
                ? Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: display.toDouble(),
                          min: 0,
                          max: 100,
                          divisions: 20,
                          onChanged: (v) =>
                              setState(() => _draggingValue = v.round()),
                          onChangeEnd: (v) {
                            widget.onUpdate(v.round());
                            setState(() => _editing = false);
                          },
                        ),
                      ),
                      SizedBox(
                          width: 36,
                          child: Text('$display%',
                              style: theme.textTheme.labelSmall)),
                    ],
                  )
                : GestureDetector(
                    onTap: () => setState(() {
                      _editing = true;
                      _draggingValue = widget.task.percent;
                    }),
                    child: Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: display / 100,
                              child: Container(
                                height: 24,
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          Text(display > 0 ? '$display%' : '未开始',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: display == 0
                                    ? scheme.outline
                                    : (display > 50
                                        ? scheme.onPrimary
                                        : scheme.onSurface),
                              )),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ==================== 描述字段（内联展开编辑） ====================

/// 描述字段：点击展开多行 TextField，失焦或点保存提交。
class _DescriptionField extends StatefulWidget {
  const _DescriptionField({required this.description, required this.onChanged});

  final String description;
  final ValueChanged<String> onChanged;

  @override
  State<_DescriptionField> createState() => _DescriptionFieldState();
}

class _DescriptionFieldState extends State<_DescriptionField> {
  bool _editing = false;
  late TextEditingController _ctrl;
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.description);
    _focus = FocusNode();
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_DescriptionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && widget.description != oldWidget.description) {
      _ctrl.text = widget.description;
    }
  }

  void _onFocusChange() {
    if (!_focus.hasFocus && _editing) _commit();
  }

  void _startEdit() {
    _ctrl.text = widget.description;
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _commit() {
    final v = _ctrl.text.trim();
    if (v != widget.description) widget.onChanged(v);
    setState(() => _editing = false);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (_editing) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.notes, size: 18, color: scheme.outline),
            const SizedBox(width: 10),
            SizedBox(
                width: 72,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('描述',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: scheme.outline)),
                )),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: [
                  TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    maxLines: 5,
                    minLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                          onPressed: () => setState(() => _editing = false),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: _commit, child: const Text('保存')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final empty = widget.description.trim().isEmpty;
    return _EditTile(
      icon: Icons.notes,
      label: '描述',
      value: empty ? '点击添加描述' : widget.description,
      valueColor: empty ? scheme.outline : scheme.onSurface,
      maxLines: 2,
      minLines: 2,
      trailing: const Icon(Icons.edit_outlined, size: 18),
      onTap: _startEdit,
    );
  }
}

// ==================== 标签编辑器（输入 + 选择） ====================

/// 标签字段：InputChip 展示已有标签，输入框支持检索已知标签或输入新标签。
class _TagEditor extends StatefulWidget {
  const _TagEditor({
    required this.tags,
    required this.allTags,
    required this.onChanged,
  });

  final List<String> tags;
  final List<String> allTags;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<_TagEditor> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _addTag(String v) {
    v = v.trim();
    if (v.isEmpty) return;
    if (!widget.tags.contains(v)) {
      widget.onChanged([...widget.tags, v]);
    }
    _ctrl.clear();
    _focus.requestFocus();
  }

  void _removeTag(String tag) {
    widget.onChanged(widget.tags.where((t) => t != tag).toList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.label_outline, size: 18, color: scheme.outline),
          const SizedBox(width: 10),
          SizedBox(
              width: 72,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('标签',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: scheme.outline)),
              )),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: widget.tags
                          .map((tag) => InputChip(
                                label: Text(tag),
                                onDeleted: () => _removeTag(tag),
                                deleteIconColor: scheme.outline,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                  ),
                RawAutocomplete<String>(
                  textEditingController: _ctrl,
                  focusNode: _focus,
                  optionsBuilder: (textEditingValue) {
                    final v = textEditingValue.text.trim().toLowerCase();
                    // 空输入时显示全部已知标签（排除已添加的）
                    final base = widget.allTags
                        .where((t) => !widget.tags.contains(t));
                    if (v.isEmpty) return base.take(10);
                    return base
                        .where((t) => t.toLowerCase().contains(v))
                        .take(10);
                  },
                  onSelected: _addTag,
                  fieldViewBuilder:
                      (ctx, controller, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: '输入或选择标签',
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: UnderlineInputBorder(
                          borderSide:
                              BorderSide(color: scheme.outlineVariant),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                      ),
                      onSubmitted: (v) {
                        _addTag(v);
                        onFieldSubmitted();
                      },
                    );
                  },
                  optionsViewBuilder: (ctx, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(8),
                        color: scheme.surface,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (_, i) {
                              final opt = options.elementAt(i);
                              return ListTile(
                                dense: true,
                                title: Text(opt),
                                onTap: () => onSelected(opt),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 下拉选择字段（类 web select） ====================

/// 下拉选项数据。
class _DropdownOption<T> {
  const _DropdownOption({
    required this.value,
    required this.label,
    this.icon,
    this.color,
  });

  final T value;
  final String label;
  final IconData? icon;
  final Color? color;
}

/// 下拉选择字段：当前值显示在带边框的"选择框"中，点击展开菜单。
///
/// 视觉参照 web `<select>` 控件，使用 Material 3 的 [DropdownMenu] 实现，
/// 自带边框、下拉箭头、hover/focus 高亮。
class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final T value;
  final List<_DropdownOption<T>> options;
  final ValueChanged<T> onChanged;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
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
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: scheme.outline),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Theme(
              data: theme.copyWith(
                inputDecorationTheme: const InputDecorationTheme(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
              child: DropdownMenu<T>(
                initialSelection: value,
                expandedInsets: EdgeInsets.zero,
                enableSearch: false,
                requestFocusOnTap: false,
                onSelected: (v) {
                  if (v != null) onChanged(v);
                },
                dropdownMenuEntries: options
                    .map((o) => DropdownMenuEntry<T>(
                          value: o.value,
                          label: o.label,
                          leadingIcon: o.icon != null
                              ? Icon(o.icon,
                                  size: 18, color: o.color ?? scheme.outline)
                              : null,
                          trailingIcon: o.value == value
                              ? Icon(Icons.check,
                                  size: 16, color: scheme.primary)
                              : null,
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 可编辑字段行 ====================

class _EditTile extends StatelessWidget {
  const _EditTile({
    // ignore: unused_element_parameter
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.iconColor,
    this.valueColor,
    this.trailing,
    this.style,
    this.maxLines = 1,
    this.minLines,
    this.mono = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? valueColor;
  final Widget? trailing;
  final TextStyle? style;
  final int? maxLines;
  final int? minLines;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final effectiveStyle = style ?? theme.textTheme.bodyMedium;
    // 计算最小高度：minLines × 行高（fontSize × height）
    final fontSize = effectiveStyle?.fontSize ?? 14.0;
    final lineHeight = effectiveStyle?.height ?? 1.43;
    final minHeight = (minLines ?? 1) * fontSize * lineHeight;
    final multiLine = minLines != null && minLines! > 1;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: multiLine
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: iconColor ?? scheme.outline),
            const SizedBox(width: 10),
            SizedBox(
              width: 72,
              child: Padding(
                padding: EdgeInsets.only(top: multiLine ? 2 : 0),
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.outline,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Text(
                  value,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: effectiveStyle?.copyWith(
                    color: valueColor,
                    fontFamily: mono ? 'monospace' : null,
                  ),
                ),
              ),
            ),
            if (trailing != null)
              Padding(
                padding: EdgeInsets.only(top: multiLine ? 2 : 0),
                child: trailing,
              ),
          ],
        ),
      ),
    );
  }
}

/// 解析日历颜色（hex 字符串 → Color）。
Color? _parseCalendarColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  try {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  } catch (_) {
    return null;
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
        TaskStatus.needsAction => '需要操作',
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


