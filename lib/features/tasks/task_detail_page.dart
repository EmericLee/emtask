import 'dart:math' as math;

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
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
    // 详情页整体向浅色偏移（surfaceBright），与任务列表背景形成层次区分
    final scheme = Theme.of(context).colorScheme;
    // 监听任务列表变化，外部修改后同步刷新（如任务条内联编辑标题）
    ref.listen(taskListProvider, (prev, next) {
      if (_isNew || _loaded == null) return;
      next.whenData((_) => _refreshFromExternal());
    });
    return Scaffold(
      backgroundColor: scheme.surfaceBright,
      appBar: AppBar(
        backgroundColor: scheme.surfaceBright,
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
          child: Text(
            _loadError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
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
  const TaskDetailPanel({super.key, required this.taskId, this.onClose});

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
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
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
    // 详情页整体向浅色偏移（surfaceBright），与左侧任务列表背景形成层次区分
    final scheme = Theme.of(context).colorScheme;
    // 监听任务列表变化，外部修改后同步刷新（如任务条内联编辑标题）
    ref.listen(taskListProvider, (prev, next) {
      if (_loaded == null) return;
      next.whenData((_) => _refreshFromExternal());
    });
    return Scaffold(
      backgroundColor: scheme.surfaceBright,
      appBar: AppBar(
        backgroundColor: scheme.surfaceBright,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onClose,
          tooltip: '关闭',
        ),
        title: const Text('任务详情'),
        actions: [
          // 同步状态红点标志：dirty 时红色，已同步时灰色，点击查看详细同步信息
          if (_loaded != null)
            Tooltip(
              message: _loaded!.dirty ? '待同步' : '已同步',
              child: InkWell(
                onTap: () => _showSyncInfo(context),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _loaded!.dirty
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.outline,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
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

  /// 弹出同步信息面板（BottomSheet），展示 UID/HREF/ETag/时间戳等调试信息。
  void _showSyncInfo(BuildContext context) {
    final t = _loaded;
    if (t == null) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _SyncInfoSheet(task: t),
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
          child: Text(
            _loadError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
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
    await widget.onUpdate(
      (x) => x.copyWith(status: s, completed: completed, percent: percent),
    );
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
    await widget.onUpdate(
      (t) => t.copyWith(percent: p, status: status, completed: completed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final task = widget.task;

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
      children: [
        // 标题（全宽，无标签，点击就地编辑）
        if (_editingTitle)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _titleCtrl,
              focusNode: _titleFocus,
              autofocus: true,
              maxLines: null,
              minLines: 1,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _commitTitle(),
              inputFormatters: [FilteringTextInputFormatter.deny('\n')],
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: '标题',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check, size: 18),
                  onPressed: _commitTitle,
                ),
              ),
            ),
          )
        else
          InkWell(
            onTap: () {
              _titleCtrl.text = task.summary;
              setState(() => _editingTitle = true);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                task.summary,
                maxLines: null,
                style: theme.textTheme.titleMedium?.copyWith(
                  decoration: task.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                  color: task.isCompleted ? scheme.outline : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        const _Divider(),
        // 描述（全宽，无标签，点击内联展开多行编辑）
        _DescriptionField(
          description: task.description,
          onChanged: (v) => widget.onUpdate((t) => t.copyWith(description: v)),
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
        // 优先级：下拉选择控件
        _DropdownField<TaskPriority>(
          icon: task.priority == TaskPriority.high
              ? Icons.star
              : Icons.star_border,
          iconColor: _priorityColor(task.priority),
          label: '优先级',
          value: task.priority,
          valueColor: scheme.outline,
          onChanged: _setPriority,
          options: [TaskPriority.none, TaskPriority.high, TaskPriority.low]
              .map(
                (p) => _DropdownOption(
                  value: p,
                  label: _priorityLabel(p),
                  icon: p == TaskPriority.high ? Icons.star : Icons.star_border,
                  color: _priorityColor(p),
                ),
              )
              .toList(),
        ),
        // 状态：下拉选择控件
        _DropdownField<TaskStatus>(
          icon: _statusIcon(task.status),
          iconColor: _statusColor(task.status, scheme),
          label: '状态',
          value: task.status,
          valueColor: scheme.outline,
          onChanged: _setStatus,
          options: TaskStatus.values
              .map(
                (s) => _DropdownOption(
                  value: s,
                  label: _statusLabel(s),
                  icon: _statusIcon(s),
                  color: _statusColor(s, scheme),
                ),
              )
              .toList(),
        ),
        const _Divider(),
        // 时间信息：开始 / 截止 / 完成
        _DateTimeField(
          icon: Icons.play_arrow_outlined,
          label: '开始时间',
          value: task.start,
          valueColor: scheme.outline,
          onSaved: (v) => widget.onUpdate((t) => t.copyWith(start: v)),
        ),
        _DateTimeField(
          icon: Icons.event_outlined,
          label: '截止时间',
          value: task.due,
          valueColor: task.isOverdue ? scheme.error : scheme.outline,
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
        // 完成度：内联 Slider（点击展开）
        _PercentEditor(task: task, onUpdate: _setPercent),
        // 所属清单：下拉选择可切换日历
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
                  .map(
                    (c) => _DropdownOption(
                      value: c.url,
                      label: c.displayName,
                      icon: Icons.calendar_today_outlined,
                      color: _parseCalendarColor(c.color),
                    ),
                  )
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
    TaskPriority.medium => Colors.blue,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(widget.icon, size: 16, color: scheme.outline),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Text(
              widget.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.outline,
              ),
            ),
          ),
          const SizedBox(width: 6),
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
                        child: Icon(
                          Icons.clear,
                          size: 16,
                          color: scheme.outline,
                        ),
                      )
                    else
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: scheme.outline,
                      ),
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

    const panelWidth = 272.0;
    final panelHeight = showTime ? 360.0 : 320.0;
    // 下方空间不足则向上弹出
    final showBelow =
        topLeft.dy + size.height + panelHeight + 16 < media.size.height;
    final top = showBelow
        ? math.min(
            topLeft.dy + size.height + 4,
            media.size.height - panelHeight - 8,
          )
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
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _date = DateTime(
      widget.initial.year,
      widget.initial.month,
      widget.initial.day,
    );
    _hour = widget.initial.hour;
    _minute = widget.initial.minute;
    _displayedMonth = DateTime(_date.year, _date.month);
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
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMonthGrid(),
                      // 时间行（仅 showTime 时显示）
                      if (widget.showTime)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 2,
                          ),
                          child: Row(
                            children: [
                              Text(
                                '时间',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.outline,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _TimeSpinner(
                                value: _hour,
                                maxValue: 23,
                                onChanged: (v) => setState(() => _hour = v),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 3),
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
                      // 按钮行：清除 / 取消 / 确定（仅时间模式显示确定）
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: widget.onClear,
                              child: const Text(
                                '清除',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                            TextButton(
                              onPressed: widget.onCancel,
                              child: const Text(
                                '取消',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                            if (widget.showTime) ...[
                              const SizedBox(width: 4),
                              FilledButton(
                                onPressed: () => widget.onConfirm(
                                  DateTime(
                                    _date.year,
                                    _date.month,
                                    _date.day,
                                    _hour,
                                    _minute,
                                  ).toUtc(),
                                ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  textStyle: const TextStyle(fontSize: 13),
                                ),
                                child: const Text('确定'),
                              ),
                            ],
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

  /// 自定义月历网格：前后月份日期填满 6×7 网格，跨月日期可点击切换月份。
  Widget _buildMonthGrid() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthFmt = DateFormat('yyyy年M月');

    final firstOfMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month,
      1,
    );
    // 周一为首列：weekday 1=周一 … 7=周日
    final gridStart = firstOfMonth.subtract(
      Duration(days: firstOfMonth.weekday - 1),
    );
    const weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 月份导航
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 18),
                onPressed: () => setState(() {
                  _displayedMonth = DateTime(
                    _displayedMonth.year,
                    _displayedMonth.month - 1,
                  );
                }),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              Text(
                monthFmt.format(_displayedMonth),
                style: theme.textTheme.titleSmall,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 18),
                onPressed: () => setState(() {
                  _displayedMonth = DateTime(
                    _displayedMonth.year,
                    _displayedMonth.month + 1,
                  );
                }),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
        // 星期表头
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              for (final w in weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        // 6 行日期
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            children: [
              for (int week = 0; week < 6; week++)
                Row(
                  children: [
                    for (int day = 0; day < 7; day++)
                      Expanded(
                        child: _buildDayCell(
                          gridStart.add(Duration(days: week * 7 + day)),
                          today,
                          scheme,
                          theme,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 单个日期单元格。
  Widget _buildDayCell(
    DateTime cellDate,
    DateTime today,
    ColorScheme scheme,
    ThemeData theme,
  ) {
    final isCurrentMonth = cellDate.month == _displayedMonth.month;
    final isToday = cellDate == today;
    final isSelected =
        cellDate.year == _date.year &&
        cellDate.month == _date.month &&
        cellDate.day == _date.day;

    Color? bgColor;
    Color? textColor = scheme.onSurface;
    if (isSelected) {
      bgColor = scheme.primary;
      textColor = scheme.onPrimary;
    } else if (isToday) {
      textColor = scheme.primary;
    }
    if (!isCurrentMonth && !isSelected) {
      textColor = scheme.outline.withValues(alpha: 0.5);
    }

    return GestureDetector(
      onTap: () {
        // 日期模式（无时间选择器）：点击即确认并关闭
        if (!widget.showTime) {
          widget.onConfirm(
            DateTime(
              cellDate.year,
              cellDate.month,
              cellDate.day,
              _hour,
              _minute,
            ).toUtc(),
          );
          return;
        }
        // 日期时间模式：仅更新选中日期，等待用户确认
        setState(() {
          _date = cellDate;
          if (!isCurrentMonth) {
            _displayedMonth = DateTime(cellDate.year, cellDate.month);
          }
        });
      },
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: isToday && !isSelected
                ? Border.all(color: scheme.primary, width: 1.5)
                : null,
          ),
          alignment: Alignment.center,
          child: FittedBox(
            child: Text(
              '${cellDate.day}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: textColor,
                fontSize: 12,
                fontWeight: isToday || isSelected ? FontWeight.w600 : null,
              ),
            ),
          ),
        ),
      ),
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
      width: 40,
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => onChanged((value + 1) % (maxValue + 1)),
            child: Icon(Icons.arrow_drop_up, size: 14, color: scheme.outline),
          ),
          Text(
            value.toString().padLeft(2, '0'),
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
              fontSize: 12,
            ),
          ),
          InkWell(
            onTap: () => onChanged((value - 1 + maxValue + 1) % (maxValue + 1)),
            child: Icon(Icons.arrow_drop_down, size: 14, color: scheme.outline),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.percent_outlined, size: 16, color: scheme.outline),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Text(
              '完成进度',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.outline,
              ),
            ),
          ),
          const SizedBox(width: 6),
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
                        child: Text(
                          '$display%',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
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
                          Text(
                            display > 0 ? '$display%' : '未开始',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: display == 0
                                  ? scheme.outline
                                  : (display > 50
                                        ? scheme.onPrimary
                                        : scheme.onSurface),
                            ),
                          ),
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
      // 编辑态：全宽多行输入框，内嵌对号确定按钮（与标题字段一致）
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextField(
          controller: _ctrl,
          focusNode: _focus,
          maxLines: 8,
          minLines: 2,
          textAlignVertical: TextAlignVertical.top,
          decoration: InputDecoration(
            hintText: '描述',
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: IconButton(
              icon: const Icon(Icons.check, size: 18),
              onPressed: _commit,
              tooltip: '保存',
            ),
          ),
        ),
      );
    }
    // 非编辑态：全宽展示描述内容（或占位文本），点击进入编辑
    final empty = widget.description.trim().isEmpty;
    return InkWell(
      onTap: _startEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          empty ? '点击添加描述' : widget.description,
          maxLines: 8,
          overflow: TextOverflow.ellipsis,
          style: empty
              ? theme.textTheme.bodyMedium?.copyWith(color: scheme.outline)
              : theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
        ),
      ),
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
    // 全宽布局（无图标、无标签前缀），标签胶囊与输入框在同一 Wrap 流式布局中
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // 标签胶囊：样式与任务条上的 _TagChip 一致，带删除按钮
          ...widget.tags.map(
            (tag) =>
                _EditableTagChip(label: tag, onDeleted: () => _removeTag(tag)),
          ),
          // 输入框：与标签同行，支持检索已知标签或输入新标签
          SizedBox(
            width: 140,
            child: RawAutocomplete<String>(
              textEditingController: _ctrl,
              focusNode: _focus,
              optionsBuilder: (textEditingValue) {
                final v = textEditingValue.text.trim().toLowerCase();
                // 空输入时显示全部已知标签（排除已添加的）
                final base = widget.allTags.where(
                  (t) => !widget.tags.contains(t),
                );
                if (v.isEmpty) return base.take(10);
                return base.where((t) => t.toLowerCase().contains(v)).take(10);
              },
              onSelected: _addTag,
              fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: '输入或选择标签',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.outline,
                    ),
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
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
          ),
        ],
      ),
    );
  }
}

/// 可删除的标签胶囊（视觉样式同任务条上的 _TagChip，带 × 删除按钮）。
class _EditableTagChip extends StatelessWidget {
  const _EditableTagChip({required this.label, required this.onDeleted});

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // 整个胶囊均可点击删除，光标变为手型
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onDeleted,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.close,
                size: 12,
                color: scheme.onSecondaryContainer.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
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
/// 视觉参照 web `<select>` 控件，使用 [DropdownButton2] 实现，
/// 行高、padding、选中态对号均可直接控制。
class _DropdownField<T> extends StatefulWidget {
  const _DropdownField({
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.iconColor,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final T value;
  final List<_DropdownOption<T>> options;
  final ValueChanged<T> onChanged;
  final Color? iconColor;
  final Color? valueColor;

  @override
  State<_DropdownField<T>> createState() => _DropdownFieldState<T>();
}

class _DropdownFieldState<T> extends State<_DropdownField<T>> {
  late final ValueNotifier<T?> _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ValueNotifier<T?>(widget.value);
  }

  @override
  void didUpdateWidget(covariant _DropdownField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _notifier.value = widget.value;
    }
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final value = widget.value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(widget.icon, size: 16, color: widget.iconColor ?? scheme.outline),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Text(
              widget.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.outline,
              ),
            ),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: DropdownButton2<T>(
              valueListenable: _notifier,
              items: widget.options
                  .map(
                    (o) => DropdownItem<T>(
                      value: o.value,
                      height: 32,
                      child: Row(
                        children: [
                          if (o.icon != null) ...[
                            Icon(
                              o.icon,
                              size: 14,
                              color: o.color ?? scheme.outline,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            o.label,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const Spacer(),
                          if (o.value == value)
                            Icon(
                              Icons.check,
                              size: 14,
                              color: scheme.primary,
                            ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              selectedItemBuilder: (_) => widget.options
                  .map(
                    (o) => Row(
                      children: [
                        if (o.icon != null) ...[
                          Icon(
                            o.icon,
                            size: 14,
                            color: o.color ?? scheme.outline,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          o.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: widget.valueColor,
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) widget.onChanged(v);
              },
              underline: const SizedBox.shrink(),
              buttonStyleData: const ButtonStyleData(
                height: 28,
                padding: EdgeInsets.symmetric(horizontal: 8),
              ),
              iconStyleData: IconStyleData(
                icon: Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: scheme.outline,
                ),
              ),
              dropdownStyleData: DropdownStyleData(
                maxHeight: 240,
                width: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: scheme.surface,
                ),
              ),
              menuItemStyleData: const MenuItemStyleData(
                padding: EdgeInsets.symmetric(horizontal: 10),
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
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: iconColor ?? scheme.outline),
            const SizedBox(width: 8),
            SizedBox(
              width: 64,
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.outline,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (trailing != null) trailing!,
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

/// 同步信息面板（用于 BottomSheet 弹出），展示任务的同步元信息。
class _SyncInfoSheet extends StatelessWidget {
  const _SyncInfoSheet({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = task;
    final fmt = DateFormat('yyyy-MM-dd HH:mm:ss');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sync_outlined, size: 20, color: scheme.outline),
              const SizedBox(width: 8),
              Text(
                '同步信息',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: t.dirty
                      ? scheme.errorContainer.withValues(alpha: 0.5)
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  t.dirty ? '待同步' : '已同步',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: t.dirty ? scheme.error : scheme.outline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
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
                  _kv('最后修改', fmt.format(t.lastModified!.toLocal()), scheme),
                _kv('待同步', t.dirty ? '是' : '否', scheme),
              ],
            ),
          ),
        ],
      ),
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
            child: Text(
              k,
              style: TextStyle(color: scheme.outline, fontSize: 12),
            ),
          ),
          Expanded(
            child: SelectableText(
              v,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
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
  late final ValueNotifier<String?> _calNotifier;

  @override
  void initState() {
    super.initState();
    _calendarUrl = widget.initialCalendarUrl;
    _calNotifier = ValueNotifier<String?>(_calendarUrl);
  }

  @override
  void dispose() {
    _summaryCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    _calNotifier.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_summaryCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入任务标题')));
      return;
    }
    if (_calendarUrl == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先在设置中配置 CalDAV 账户')));
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
      DateTime(date.year, date.month, date.day, time.hour, time.minute).toUtc(),
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
          child: widget.calendarsAsync.when(
            data: (list) {
              return DropdownButton2<String?>(
                valueListenable: _calNotifier,
                items: list
                    .map(
                      (c) => DropdownItem<String?>(
                        value: c.url,
                        height: 36,
                        child: Row(
                          children: [
                            Text(
                              c.displayName,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const Spacer(),
                            if (c.url == _calendarUrl)
                              Icon(
                                Icons.check,
                                size: 14,
                                color: scheme.primary,
                              ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                selectedItemBuilder: (_) => list
                    .map(
                      (c) => Text(
                        c.displayName,
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  _calendarUrl = v;
                  _calNotifier.value = v;
                }),
                underline: const SizedBox.shrink(),
                buttonStyleData: const ButtonStyleData(
                  height: 40,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                ),
                iconStyleData: IconStyleData(
                  icon: Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                    color: scheme.outline,
                  ),
                ),
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 240,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: scheme.surface,
                  ),
                ),
                menuItemStyleData: const MenuItemStyleData(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                ),
              );
            },
            loading: () => const SizedBox(
              height: 40,
              child: Center(child: LinearProgressIndicator()),
            ),
            error: (_, _) => const SizedBox.shrink(),
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
                    child: Row(
                      children: [
                        Icon(
                          _statusIcon(s),
                          color: _statusColor(s, Theme.of(ctx).colorScheme),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_statusLabel(s))),
                        if (s == _status) const Icon(Icons.check, size: 18),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
            if (s != null) setState(() => _status = s);
          },
        ),
        _EditTile(
          icon: _priority == TaskPriority.high ? Icons.star : Icons.star_border,
          iconColor: _priorityColor(_priority),
          label: '优先级',
          value: _priorityLabel(_priority),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: () async {
            final p = await showDialog<TaskPriority>(
              context: context,
              builder: (ctx) => SimpleDialog(
                title: const Text('选择优先级'),
                children:
                    [
                      TaskPriority.none,
                      TaskPriority.high,
                      TaskPriority.low,
                    ].map((p) {
                      return SimpleDialogOption(
                        onPressed: () => Navigator.pop(ctx, p),
                        child: Row(
                          children: [
                            Icon(
                              p == TaskPriority.high
                                  ? Icons.star
                                  : Icons.star_border,
                              color: _priorityColor(p),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(_priorityLabel(p))),
                            if (p == _priority)
                              const Icon(Icons.check, size: 18),
                          ],
                        ),
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
    TaskPriority.medium => Colors.blue,
    TaskPriority.low => Colors.blue,
  };
}
