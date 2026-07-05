import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/calendar.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_status.dart';
import '../sync/sync_providers.dart';
import 'task_providers.dart';

/// 任务列表页。
class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskListProvider);
    final calendars =
        ref.watch(calendarListProvider).valueOrNull ?? const <Calendar>[];
    final selected = ref.watch(selectedCalendarProvider);
    final completion = ref.watch(completionFilterProvider);
    final dueRange = ref.watch(dueRangeProvider);
    final sortMode = ref.watch(sortModeProvider);
    final hideCompleted = ref.watch(hideCompletedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(syncControllerProvider.notifier).sync(),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => _showFilterSheet(context, ref),
            tooltip: '过滤与排序',
          ),
        ],
      ),
      body: Column(
        children: [
          // 过滤状态摘要条
          _FilterSummaryBar(
            calendars: calendars,
            selectedCalendar: selected,
            completion: completion,
            dueRange: dueRange,
            sortMode: sortMode,
            hideCompleted: hideCompleted,
            onTap: () => _showFilterSheet(context, ref),
          ),
          // 任务列表
          Expanded(
            child: tasksAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _EmptyState(
                icon: Icons.cloud_off,
                title: '加载失败',
                message: e.toString(),
              ),
              data: (tasks) {
                final filtered = _applyFilters(
                  tasks,
                  completion: completion,
                  dueRange: dueRange,
                  hideCompleted: hideCompleted,
                );
                if (filtered.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.checklist_outlined,
                    title: '暂无任务',
                    message: '点击右下角 + 创建第一个任务',
                  );
                }
                final tree = _TaskTree(filtered, sortMode: sortMode);
                return _TaskTreeView(
                  tree: tree,
                  sortMode: sortMode,
                  onReorderRoots: (oldIndex, newIndex) async {
                    final ordered = List<Task>.from(tree.roots);
                    final moved = ordered.removeAt(oldIndex);
                    final insertAt =
                        newIndex > oldIndex ? newIndex - 1 : newIndex;
                    ordered.insert(insertAt, moved);
                    await saveSortOrders(
                        ref, ordered.map((t) => t.localId).toList());
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/tasks/new'),
        icon: const Icon(Icons.add),
        label: const Text('新建任务'),
      ),
    );
  }

  /// 应用过滤条件。
  List<Task> _applyFilters(
    List<Task> tasks, {
    required CompletionFilter completion,
    required DueRange dueRange,
    required bool hideCompleted,
  }) {
    return tasks.where((t) {
      if (t.deleted) return false;
      // 完成情况
      if (hideCompleted && t.isCompleted) return false;
      switch (completion) {
        case CompletionFilter.all:
          break;
        case CompletionFilter.active:
          if (t.isCompleted) return false;
          break;
        case CompletionFilter.completed:
          if (!t.isCompleted) return false;
          break;
      }
      // 截止时间
      if (dueRange != DueRange.anytime && t.due != null) {
        final due = t.due!.toLocal();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        switch (dueRange) {
          case DueRange.today:
            final end = today.add(const Duration(days: 1));
            if (due.isBefore(today) || !due.isBefore(end)) return false;
            break;
          case DueRange.thisWeek:
            // 本周：从今天到本周日（周一为始）
            final weekStart =
                today.subtract(Duration(days: now.weekday - 1));
            final weekEnd = weekStart.add(const Duration(days: 7));
            if (due.isBefore(weekStart) || !due.isBefore(weekEnd)) {
              return false;
            }
            break;
          case DueRange.thisMonth:
            final monthStart = DateTime(now.year, now.month, 1);
            final monthEnd = DateTime(now.year, now.month + 1, 1);
            if (due.isBefore(monthStart) || !due.isBefore(monthEnd)) {
              return false;
            }
            break;
          case DueRange.anytime:
            break;
        }
      }
      return true;
    }).toList();
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _FilterSheet(),
    );
  }
}

/// 过滤状态摘要条。
class _FilterSummaryBar extends StatelessWidget {
  const _FilterSummaryBar({
    required this.calendars,
    required this.selectedCalendar,
    required this.completion,
    required this.dueRange,
    required this.sortMode,
    required this.hideCompleted,
    required this.onTap,
  });

  final List<Calendar> calendars;
  final String? selectedCalendar;
  final CompletionFilter completion;
  final DueRange dueRange;
  final SortMode sortMode;
  final bool hideCompleted;
  final VoidCallback onTap;

  String get _calendarLabel {
    if (selectedCalendar == null) return '全部清单';
    final c = calendars.firstWhere(
      (c) => c.url == selectedCalendar,
      orElse: () => calendars.first,
    );
    return c.displayName;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <String>[
      _calendarLabel,
      switch (completion) {
        CompletionFilter.all => '全部状态',
        CompletionFilter.active => '未完成',
        CompletionFilter.completed => '已完成',
      },
      switch (dueRange) {
        DueRange.anytime => '不限时间',
        DueRange.today => '今天',
        DueRange.thisWeek => '本周',
        DueRange.thisMonth => '本月',
      },
      switch (sortMode) {
        SortMode.manual => '手动排序',
        SortMode.alphabetical => '字母排序',
        SortMode.dueDate => '按截止时间',
        SortMode.edited => '按编辑时间',
      },
      if (hideCompleted) '隐藏已完成',
    ];

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: chips
                  .map((c) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Chip(
                          label: Text(c),
                          labelStyle: theme.textTheme.labelSmall,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

/// 过滤/排序底部弹窗。
class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final calendars =
        ref.watch(calendarListProvider).valueOrNull ?? const <Calendar>[];
    final selected = ref.watch(selectedCalendarProvider);
    final completion = ref.watch(completionFilterProvider);
    final dueRange = ref.watch(dueRangeProvider);
    final sortMode = ref.watch(sortModeProvider);
    final hideCompleted = ref.watch(hideCompletedProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('过滤与排序',
                    style: theme.textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    ref.read(selectedCalendarProvider.notifier).state = null;
                    ref.read(completionFilterProvider.notifier).state =
                        CompletionFilter.all;
                    ref.read(dueRangeProvider.notifier).state =
                        DueRange.anytime;
                    ref.read(sortModeProvider.notifier).state =
                        SortMode.dueDate;
                    ref.read(hideCompletedProvider.notifier).state = false;
                  },
                  child: const Text('重置'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 清单
            Text('清单', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                _ChoiceChip(
                  label: '全部',
                  selected: selected == null,
                  onSelected: (_) => ref
                      .read(selectedCalendarProvider.notifier)
                      .state = null,
                ),
                ...calendars.map((c) => _ChoiceChip(
                      label: c.displayName,
                      selected: selected == c.url,
                      onSelected: (_) => ref
                          .read(selectedCalendarProvider.notifier)
                          .state = c.url,
                    )),
              ],
            ),
            const SizedBox(height: 12),
            // 完成情况
            Text('完成情况', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: CompletionFilter.values
                  .map((c) => _ChoiceChip(
                        label: switch (c) {
                          CompletionFilter.all => '全部',
                          CompletionFilter.active => '未完成',
                          CompletionFilter.completed => '已完成',
                        },
                        selected: completion == c,
                        onSelected: (_) => ref
                            .read(completionFilterProvider.notifier)
                            .state = c,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            // 截止时间
            Text('截止时间', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: DueRange.values
                  .map((d) => _ChoiceChip(
                        label: switch (d) {
                          DueRange.anytime => '不限',
                          DueRange.today => '今天',
                          DueRange.thisWeek => '本周',
                          DueRange.thisMonth => '本月',
                        },
                        selected: dueRange == d,
                        onSelected: (_) => ref
                            .read(dueRangeProvider.notifier)
                            .state = d,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            // 排序
            Text('排序方式', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: SortMode.values
                  .map((s) => _ChoiceChip(
                        label: switch (s) {
                          SortMode.manual => '手动',
                          SortMode.alphabetical => '字母',
                          SortMode.dueDate => '截止时间',
                          SortMode.edited => '编辑时间',
                        },
                        selected: sortMode == s,
                        onSelected: (_) => ref
                            .read(sortModeProvider.notifier)
                            .state = s,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            // 隐藏已完成
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('隐藏已完成'),
              value: hideCompleted,
              onChanged: (v) => ref
                  .read(hideCompletedProvider.notifier)
                  .state = v,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// 任务树：按 parentUid 建立父子关系，并按排序方式排序。
class _TaskTree {
  _TaskTree(List<Task> all, {required SortMode sortMode})
      : _sortMode = sortMode {
    final active = all.where((t) => !t.deleted).toList();
    for (final t in active) {
      final p = t.parentUid;
      if (p == null || p.isEmpty) {
        _roots.add(t);
      } else {
        _children.putIfAbsent(p, () => []).add(t);
      }
    }
    // 预计算每个任务的聚合时间（用于排序）
    _aggregateTimes(active);
    _roots.sort(_compareByMode);
    for (final k in _children.keys) {
      _children[k]!.sort(_compareByMode);
    }
  }

  final SortMode _sortMode;
  final List<Task> _roots = [];
  final Map<String, List<Task>> _children = {};

  /// 聚合的完成时间（所有子任务最近完成时间）。
  final Map<String, DateTime> _aggCompleted = {};

  /// 聚合的编辑时间（所有子任务最新编辑时间）。
  final Map<String, DateTime> _aggEdited = {};

  List<Task> get roots => _roots;
  List<Task> childrenOf(String? parentUid) =>
      parentUid == null ? _roots : (_children[parentUid] ?? const []);

  /// 递归计算聚合时间：父任务的完成/编辑时间 = max(自身, 所有子任务)。
  void _aggregateTimes(List<Task> all) {
    final byUid = {for (final t in all) t.uid: t};
    DateTime? aggCompleted(String uid, Set<String> visiting) {
      if (visiting.contains(uid)) return null; // 防环
      visiting.add(uid);
      final t = byUid[uid];
      DateTime? latest = t?.completed;
      for (final child in _children[uid] ?? const <Task>[]) {
        final c = aggCompleted(child.uid, visiting);
        if (c != null && (latest == null || c.isAfter(latest))) {
          latest = c;
        }
      }
      visiting.remove(uid);
      return latest;
    }

    DateTime? aggEdited(String uid, Set<String> visiting) {
      if (visiting.contains(uid)) return null;
      visiting.add(uid);
      final t = byUid[uid];
      DateTime? latest = t?.lastModified ?? t?.localModifiedAt;
      for (final child in _children[uid] ?? const <Task>[]) {
        final c = aggEdited(child.uid, visiting);
        if (c != null && (latest == null || c.isAfter(latest))) {
          latest = c;
        }
      }
      visiting.remove(uid);
      return latest;
    }

    for (final t in all) {
      final c = aggCompleted(t.uid, {});
      if (c != null) _aggCompleted[t.uid] = c;
      final e = aggEdited(t.uid, {});
      if (e != null) _aggEdited[t.uid] = e;
    }
  }

  int _compareByMode(Task a, Task b) {
    // 未完成永远在已完成之前（除非用户手动排序）
    if (_sortMode != SortMode.manual && a.isCompleted != b.isCompleted) {
      return a.isCompleted ? 1 : -1;
    }
    switch (_sortMode) {
      case SortMode.manual:
        // 按 sortOrder（X-APPLE-SORT-ORDER）排序，null 视为最大（排末尾）
        final aso = a.sortOrder ?? 1 << 30;
        final bso = b.sortOrder ?? 1 << 30;
        final cmp = aso.compareTo(bso);
        if (cmp != 0) return cmp;
        // sortOrder 相同时按 localId 稳定
        return a.localId.compareTo(b.localId);
      case SortMode.alphabetical:
        return a.summary.toLowerCase().compareTo(b.summary.toLowerCase());
      case SortMode.dueDate:
        final ad = a.due, bd = b.due;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      case SortMode.edited:
        final ae = _aggEdited[a.uid] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final be = _aggEdited[b.uid] ?? DateTime.fromMillisecondsSinceEpoch(0);
        return be.compareTo(ae); // 最新编辑在前
    }
  }
}

/// 任务树视图：可展开/折叠子任务，支持一键展开与手动拖拽排序。
class _TaskTreeView extends ConsumerStatefulWidget {
  const _TaskTreeView({
    required this.tree,
    required this.sortMode,
    this.onReorderRoots,
  });

  final _TaskTree tree;
  final SortMode sortMode;
  final void Function(int oldIndex, int newIndex)? onReorderRoots;

  @override
  ConsumerState<_TaskTreeView> createState() => _TaskTreeViewState();
}

class _TaskTreeViewState extends ConsumerState<_TaskTreeView> {
  final Set<String> _expanded = {};
  bool _expandAll = false;

  bool get _canReorder =>
      widget.sortMode == SortMode.manual &&
      widget.onReorderRoots != null;

  void _toggleAll(bool expand) {
    setState(() {
      _expandAll = expand;
      _expanded.clear();
      if (expand) {
        _collectAllUids(widget.tree.roots);
      }
    });
  }

  void _collectAllUids(List<Task> tasks) {
    for (final t in tasks) {
      if (widget.tree.childrenOf(t.uid).isNotEmpty) {
        _expanded.add(t.uid);
        _collectAllUids(widget.tree.childrenOf(t.uid));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // 工具栏
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () => _toggleAll(!_expandAll),
                icon: Icon(_expandAll
                    ? Icons.unfold_less_outlined
                    : Icons.unfold_more_outlined),
                label: Text(_expandAll ? '全部折叠' : '全部展开'),
              ),
              const Spacer(),
              if (_canReorder)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.drag_indicator,
                          size: 14, color: theme.colorScheme.outline),
                      const SizedBox(width: 4),
                      Text('可拖拽排序',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.colorScheme.outline)),
                    ],
                  ),
                ),
              Text(
                '${widget.tree.roots.length} 个任务',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: _canReorder
              ? ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  buildDefaultDragHandles: false,
                  itemCount: widget.tree.roots.length,
                  onReorder: widget.onReorderRoots!,
                  proxyDecorator: (child, index, animation) => Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: child,
                  ),
                  itemBuilder: (context, i) {
                    final task = widget.tree.roots[i];
                    return ReorderableDragStartListener(
                      key: ValueKey('root-${task.uid}'),
                      index: i,
                      child: _buildNode(task, depth: 0),
                    );
                  },
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: widget.tree.roots.length,
                  itemBuilder: (context, i) =>
                      _buildNode(widget.tree.roots[i], depth: 0),
                ),
        ),
      ],
    );
  }

  Widget _buildNode(Task task, {required int depth}) {
    final kids = widget.tree.childrenOf(task.uid);
    final hasKids = kids.isNotEmpty;
    final isExpanded = _expanded.contains(task.uid);

    return Column(
      children: [
        _TaskTile(
          task: task,
          depth: depth,
          hasChildren: hasKids,
          isExpanded: isExpanded,
          childCount: kids.length,
          onToggle: hasKids
              ? () => setState(() {
                    if (isExpanded) {
                      _expanded.remove(task.uid);
                      _expandAll = false;
                    } else {
                      _expanded.add(task.uid);
                    }
                  })
              : null,
        ),
        if (hasKids && isExpanded)
          ...kids.map((k) => _buildNode(k, depth: depth + 1)),
      ],
    );
  }
}

/// 单个任务条目（支持就地展开精简详情）。
class _TaskTile extends StatefulWidget {
  const _TaskTile({
    required this.task,
    required this.depth,
    required this.hasChildren,
    required this.isExpanded,
    required this.childCount,
    this.onToggle,
  });

  final Task task;
  final int depth;
  final bool hasChildren;
  final bool isExpanded;
  final int childCount;
  final VoidCallback? onToggle;

  @override
  State<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<_TaskTile> {
  bool _selected = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmtDate = DateFormat('MM-dd');
    final fmtTime = DateFormat('HH:mm');
    final t = widget.task;

    return Padding(
      padding: EdgeInsets.only(left: widget.depth * 16.0),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        color: _selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : null,
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _selected = !_selected),
              onLongPress: () => context.go('/tasks/${t.localId}'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 展开/折叠按钮
                    if (widget.hasChildren)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 28, minHeight: 28),
                        onPressed: widget.onToggle,
                        icon: Icon(widget.isExpanded
                            ? Icons.expand_less
                            : Icons.expand_more),
                      )
                    else
                      const SizedBox(width: 28, height: 28),
                    const SizedBox(width: 4),
                    _StatusIcon(status: t.status),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 标题行
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  t.summary,
                                  style: t.isCompleted
                                      ? theme.textTheme.bodyLarge?.copyWith(
                                          decoration:
                                              TextDecoration.lineThrough,
                                          color: theme.colorScheme.outline,
                                        )
                                      : theme.textTheme.bodyLarge,
                                ),
                              ),
                              if (t.dirty)
                                Icon(Icons.sync_problem,
                                    size: 16,
                                    color: theme.colorScheme.tertiary),
                              if (widget.hasChildren)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Text(
                                    '${widget.childCount}',
                                    style: theme.textTheme.labelSmall
                                        ?.copyWith(
                                            color:
                                                theme.colorScheme.outline),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // 元信息行
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (t.due != null)
                                _MetaChip(
                                  icon: Icons.event_outlined,
                                  text:
                                      '截止 ${fmtDate.format(t.due!.toLocal())} ${fmtTime.format(t.due!.toLocal())}',
                                  color: t.isOverdue
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.outline,
                                ),
                              if (t.start != null && !t.isCompleted)
                                _MetaChip(
                                  icon: Icons.play_arrow_outlined,
                                  text:
                                      '开始 ${fmtDate.format(t.start!.toLocal())}',
                                  color: theme.colorScheme.outline,
                                ),
                              if (t.priority != TaskPriority.none)
                                _PriorityChip(priority: t.priority),
                              if (t.percent > 0 && !t.isCompleted)
                                _MetaChip(
                                  icon: Icons.percent_outlined,
                                  text: '${t.percent}%',
                                  color: theme.colorScheme.secondary,
                                ),
                              // 分类标签符号
                              if (t.categories.isNotEmpty)
                                _MetaChip(
                                  icon: Icons.label_outlined,
                                  text: t.categories.join(', '),
                                  color: theme.colorScheme.tertiary,
                                ),
                            ],
                          ),
                          // 描述摘要（首行）
                          if (t.description.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                t.description.trim().split('\n').first,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: theme.hintColor),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 就地展开的精简详情
            if (_selected) _buildQuickDetails(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDetails(BuildContext context, ThemeData theme) {
    final t = widget.task;
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 0, 8, 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (t.description.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Text(
                t.description.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (t.created != null)
            _detailRow('创建', fmt.format(t.created!.toLocal())),
          if (t.lastModified != null)
            _detailRow('修改', fmt.format(t.lastModified!.toLocal())),
          if (t.completed != null)
            _detailRow('完成', fmt.format(t.completed!.toLocal())),
          _detailRow('UID', t.uid),
          if (t.parentUid != null) _detailRow('父任务', t.parentUid!),
          // 操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => context.go('/tasks/${t.localId}'),
                child: const Text('查看详情'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(label,
                style: TextStyle(
                    color: Theme.of(context).hintColor, fontSize: 11)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 元信息小标签。
class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 2),
        Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontFamily: 'monospace',
              ),
        ),
      ],
    );
  }
}

/// 优先级标签。
class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});
  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (priority) {
      TaskPriority.high => ('高', Colors.red),
      TaskPriority.medium => ('中', Colors.orange),
      TaskPriority.low => ('低', Colors.blue),
      TaskPriority.none => ('', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        'P $label',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return switch (status) {
      TaskStatus.completed =>
        Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 22),
      TaskStatus.inProcess => Icon(Icons.pending_actions,
          color: theme.colorScheme.secondary, size: 22),
      TaskStatus.cancelled => Icon(Icons.cancel_outlined,
          color: theme.colorScheme.outline, size: 22),
      TaskStatus.needsAction => Icon(Icons.radio_button_unchecked,
          color: theme.colorScheme.outline, size: 22),
    };
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
