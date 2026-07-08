import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/providers.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_status.dart';
import '../sync/sync_providers.dart';
import 'task_detail_page.dart';
import 'task_list_pdf.dart';
import 'task_providers.dart';

/// 宽屏下当前选中的任务 ID（用于主从布局右侧详情面板）。
final selectedTaskIdProvider = StateProvider<int?>((ref) => null);

/// 宽屏阈值（与 NavigationRail 扩展阈值一致）。
const _wideScreenThreshold = 1100.0;

/// PDF 生成所需的数据包（避免两个按钮重复计算）。
class _PdfData {
  final Map<String, List<Task>> groups;
  final Map<String, Color> calendarColors;
  final OrphanDisplayMode orphanMode;
  final List<Task> allTasks;

  const _PdfData({
    required this.groups,
    required this.calendarColors,
    required this.orphanMode,
    required this.allTasks,
  });
}

/// 已隐藏完成任务的小时数（可配置，默认 24 小时）。
final _hideCompletedHoursProvider = StateProvider<int>((ref) => 24);

/// “当前”页面专用排序方式（默认手动排序，同步 Nextcloud sortOrder）。
final _currentSortModeProvider = StateProvider<SortMode>((ref) => SortMode.manual);

/// 调试开关：是否在列表中显示每个任务的 sortOrder。
final _debugSortOrderProvider = StateProvider<bool>((ref) => false);

/// 日历 URL 到显示名称的映射。
final _calendarNameMapProvider = FutureProvider<Map<String, String>>((ref) async {
  final repo = ref.watch(calendarRepositoryProvider);
  final calendars = await repo.getAll();
  return {for (final c in calendars) c.url: c.displayName};
});

/// 日历 URL 到颜色的映射。
final _calendarColorMapProvider = FutureProvider<Map<String, Color>>((ref) async {
  final repo = ref.watch(calendarRepositoryProvider);
  final calendars = await repo.getAll();
  return {
    for (final c in calendars) c.url: _parseCalendarColor(c.color),
  };
});

/// 当前选中的标签过滤（'__all__' 表示不过滤）。
final _selectedTagProvider = StateProvider<String?>((ref) => '__all__');

/// 当前选中的清单过滤（null 表示不过滤）。
final _selectedCalendarProvider = StateProvider<String?>((ref) => null);

/// 当前过滤条件下可用的标签集合（派生自任务列表与隐藏时长，自动重算）。
final _availableTagsProvider = Provider<Set<String>>((ref) {
  final tasksAsync = ref.watch(taskListProvider);
  final hideHours = ref.watch(_hideCompletedHoursProvider);
  final tasks = tasksAsync.valueOrNull ?? const <Task>[];
  final now = DateTime.now().toUtc();
  final cutoff = now.subtract(Duration(hours: hideHours));
  final tags = <String>{};
  for (final t in tasks) {
    if (t.deleted) continue;
    if (t.isCompleted && t.completed != null && t.completed!.isBefore(cutoff)) {
      continue;
    }
    tags.addAll(t.categories);
  }
  return tags;
});

/// “当前”树形任务列表页，按日历分组展示。
///
/// 采用扁平化条目设计：白色背景、默认全部展开、悬停显示完成按钮、
/// 右侧标签/日期/更多/星标，贴合政务办公类任务清单风格。
class MyWorkPage extends ConsumerWidget {
  const MyWorkPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskListProvider);
    final calendarNamesAsync = ref.watch(_calendarNameMapProvider);
    final calendarColorsAsync = ref.watch(_calendarColorMapProvider);
    final hideHours = ref.watch(_hideCompletedHoursProvider);
    final sortMode = ref.watch(_currentSortModeProvider);
    final selectedTag = ref.watch(_selectedTagProvider);
    final selectedCalendar = ref.watch(_selectedCalendarProvider);
    final debugSort = ref.watch(_debugSortOrderProvider);
    final availableTags = ref.watch(_availableTagsProvider);
    final orphanMode = ref.watch(orphanDisplayModeProvider);
    final syncState = ref.watch(syncControllerProvider);
    final pendingCount = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final isWide = MediaQuery.of(context).size.width > _wideScreenThreshold;
    final selectedTaskId = ref.watch(selectedTaskIdProvider);

    // 执行同步并显示结果提示
    Future<void> doSync() async {
      final result = await ref.read(syncControllerProvider.notifier).sync();
      if (!context.mounted) return;
      if (result.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('同步失败：${result.error}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        final parts = <String>[];
        if (result.uploaded > 0) parts.add('↑${result.uploaded}');
        if (result.downloaded > 0) parts.add('↓${result.downloaded}');
        if (result.deleted > 0) parts.add('✗${result.deleted}');
        final msg = parts.isEmpty ? '同步完成，无变更' : '同步完成 ${parts.join(' ')}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    // 准备 PDF 数据：复用当前过滤、排序、分组逻辑。
    // 返回 null 表示无可打印任务（已弹出提示）。
    Future<_PdfData?> preparePdfData() async {
      final tasks = ref.read(taskListProvider).valueOrNull;
      if (tasks == null || tasks.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('没有可打印的任务')),
          );
        }
        return null;
      }
      final calendarNames =
          ref.read(_calendarNameMapProvider).valueOrNull ?? {};
      final calendarColors =
          ref.read(_calendarColorMapProvider).valueOrNull ?? {};
      final hideHoursNow = ref.read(_hideCompletedHoursProvider);
      final sortModeNow = ref.read(_currentSortModeProvider);
      final selectedTagNow = ref.read(_selectedTagProvider);
      final orphanModeNow = ref.read(orphanDisplayModeProvider);

      final visibleTasks = _applyFilters(tasks, hideHours: hideHoursNow);
      final selectedCalendarNow = ref.read(_selectedCalendarProvider);
      final pdfTasks = selectedCalendarNow != null
          ? visibleTasks
              .where((t) => t.calendarUrl == selectedCalendarNow)
              .toList()
          : visibleTasks;
      final isTagFiltered =
          selectedTagNow != null && selectedTagNow != '__all__';
      final matchedTasks = isTagFiltered
          ? pdfTasks
              .where((t) => t.categories.contains(selectedTagNow))
              .toList()
          : pdfTasks;
      final displayTasks = isTagFiltered &&
              orphanModeNow == OrphanDisplayMode.tree
          ? _withAncestors(matchedTasks, allTasks: visibleTasks)
          : matchedTasks;
      final sortedTasks = _applySort(displayTasks, sortMode: sortModeNow);
      final groups = _groupByCalendar(sortedTasks, calendarNames);
      if (groups.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('没有可打印的任务')),
          );
        }
        return null;
      }
      return _PdfData(
        groups: groups,
        calendarColors: calendarColors,
        orphanMode: orphanModeNow,
        allTasks: visibleTasks,
      );
    }

    // 直接导出 PDF 文件（不经过打印机对话框）。
    Future<void> onExportPdf() async {
      final data = await preparePdfData();
      if (data == null || !context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在生成 PDF...'),
          duration: Duration(seconds: 2),
        ),
      );

      try {
        final bytes = await buildTaskListPdf(
          groups: data.groups,
          calendarColors: data.calendarColors,
          orphanMode: data.orphanMode,
          allTasks: data.allTasks,
        );
        final fileName =
            '当前任务清单_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

        // 尝试弹出系统保存对话框；Linux 上可能缺少 zenity 等依赖，失败时回退到 ~/Downloads。
        String? savePath;
        try {
          savePath = await FilePicker.platform.saveFile(
            dialogTitle: '保存 PDF 文件',
            fileName: fileName,
            type: FileType.custom,
            allowedExtensions: ['pdf'],
            bytes: bytes,
          );
        } catch (_) {
          // zenity 未安装等情况，savePath 保持 null，下方回退处理
          savePath = null;
        }

        // 对话框取消或不可用时回退到下载目录
        if (savePath == null || savePath.isEmpty) {
          final dir = await getDownloadsDirectory();
          savePath = '${dir?.path ?? Platform.environment['HOME'] ?? '.'}/$fileName';
        }

        final file = File(savePath);
        await file.writeAsBytes(bytes);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已保存：$savePath')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('生成 PDF 失败：$e')),
          );
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        title: const Row(
          children: [
            Icon(
              Icons.work_outline,
              size: 32,
            ),
            SizedBox(width: 10),
            Text('当前'),
          ],
        ),
        actions: [
          // 按清单过滤
          _CalendarFilterMenu(
            calendarsAsync: calendarNamesAsync,
            selected: selectedCalendar,
            onSelected: (url) =>
                ref.read(_selectedCalendarProvider.notifier).state = url,
          ),
          // 排序方式切换
          _SortModeMenu(
            current: sortMode,
            onSelected: (m) => ref.read(_currentSortModeProvider.notifier).state = m,
          ),
          // 标签快速过滤
          _TagFilterMenu(
            tags: availableTags,
            selectedTag: selectedTag,
            onSelected: (tag) => ref.read(_selectedTagProvider.notifier).state = tag,
          ),
          // 隐藏时长快速设置
          _HideHoursMenu(
            current: hideHours,
            onSelected: (h) => ref.read(_hideCompletedHoursProvider.notifier).state = h,
          ),
          // sortOrder 调试开关
          IconButton(
            tooltip: '显示/隐藏排序值',
            icon: Icon(
              debugSort ? Icons.code : Icons.code_off,
              color: debugSort ? Colors.blue : null,
            ),
            onPressed: () => ref.read(_debugSortOrderProvider.notifier).state = !debugSort,
          ),
          // 导出 PDF
          IconButton(
            tooltip: '导出 PDF 文件',
            icon: const Icon(Icons.download_outlined),
            onPressed: onExportPdf,
          ),
          // 同步按钮：未同步时高亮+角标
          _SyncButton(
            running: syncState.running,
            pendingCount: pendingCount,
            onPressed: doSync,
          ),
        ],
      ),
      body: _buildBody(
        context,
        ref,
        tasksAsync: tasksAsync,
        calendarNamesAsync: calendarNamesAsync,
        calendarColorsAsync: calendarColorsAsync,
        hideHours: hideHours,
        sortMode: sortMode,
        selectedTag: selectedTag,
        selectedCalendar: selectedCalendar,
        debugSort: debugSort,
        orphanMode: orphanMode,
        isWide: isWide,
        selectedTaskId: selectedTaskId,
      ),
    );
  }

  /// 构建主体：宽屏显示主从布局（列表+详情侧栏），窄屏仅列表。
  Widget _buildBody(
    BuildContext context,
    WidgetRef ref, {
    required AsyncValue<List<Task>> tasksAsync,
    required AsyncValue<Map<String, String>> calendarNamesAsync,
    required AsyncValue<Map<String, Color>> calendarColorsAsync,
    required int hideHours,
    required SortMode sortMode,
    required String? selectedTag,
    required String? selectedCalendar,
    required bool debugSort,
    required OrphanDisplayMode orphanMode,
    required bool isWide,
    required int? selectedTaskId,
  }) {
    final listWidget = tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _EmptyState(
        icon: Icons.cloud_off,
        title: '加载失败',
        message: e.toString(),
      ),
      data: (tasks) {
        final calendarNames = calendarNamesAsync.valueOrNull ?? {};
        final calendarColors = calendarColorsAsync.valueOrNull ?? {};
        var visibleTasks = _applyFilters(tasks, hideHours: hideHours);
        if (selectedCalendar != null) {
          visibleTasks = visibleTasks
              .where((t) => t.calendarUrl == selectedCalendar)
              .toList();
        }
        final isTagFiltered =
            selectedTag != null && selectedTag != '__all__';
        final matchedTasks = isTagFiltered
            ? visibleTasks
                .where((t) => t.categories.contains(selectedTag))
                .toList()
            : visibleTasks;
        final displayTasks = isTagFiltered &&
                orphanMode == OrphanDisplayMode.tree
            ? _withAncestors(matchedTasks, allTasks: visibleTasks)
            : matchedTasks;
        final sortedTasks = _applySort(displayTasks, sortMode: sortMode);
        final groups = _groupByCalendar(sortedTasks, calendarNames);
        if (groups.isEmpty) {
          return const _EmptyState(
            icon: Icons.work_outline,
            title: '暂无任务',
            message: '当前没有待办任务',
          );
        }
        return _CurrentTaskList(
          groups: groups,
          calendarColors: calendarColors,
          debugSortOrder: debugSort,
          orphanMode: orphanMode,
          allTasks: visibleTasks,
          isWide: isWide,
        );
      },
    );

    if (!isWide) return listWidget;

    // 宽屏：列表 + 可收缩详情侧栏
    return _WideScreenBody(
      listWidget: listWidget,
      selectedTaskId: selectedTaskId,
      onClosePanel: () =>
          ref.read(selectedTaskIdProvider.notifier).state = null,
    );
  }

  /// 过滤：移除已删除任务，以及已完成超过指定小时数的任务。
  List<Task> _applyFilters(List<Task> tasks, {required int hideHours}) {
    final now = DateTime.now().toUtc();
    final cutoff = now.subtract(Duration(hours: hideHours));
    return tasks.where((t) {
      if (t.deleted) return false;
      if (t.isCompleted && t.completed != null && t.completed!.isBefore(cutoff)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// 树状模式：向上追溯父任务链，把匹配任务及其所有祖先都包含进来。
  /// 保持原有任务顺序，去重。
  List<Task> _withAncestors(List<Task> matched, {required List<Task> allTasks}) {
    if (matched.isEmpty) return matched;
    final uidToTask = <String, Task>{
      for (final t in allTasks) t.uid: t,
    };
    final result = <Task>[];
    final added = <String>{};
    void addWithAncestors(Task t) {
      if (added.contains(t.uid)) return;
      added.add(t.uid);
      final p = t.parentUid;
      if (p != null && p.isNotEmpty && uidToTask.containsKey(p)) {
        addWithAncestors(uidToTask[p]!);
      }
      result.add(t);
    }

    for (final t in matched) {
      addWithAncestors(t);
    }
    return result;
  }

  /// 按指定排序方式对任务排序（不修改父子关系）。
  List<Task> _applySort(List<Task> tasks, {required SortMode sortMode}) {
    final compare = _compareByMode(sortMode);
    return [...tasks]..sort(compare);
  }

  /// 排序比较器。
  static int Function(Task, Task) _compareByMode(SortMode mode) {
    return (a, b) {
      // 手动排序：优先使用 Nextcloud / Apple 同步过来的 sortOrder。
      if (mode == SortMode.manual) {
        final aso = a.sortOrder ?? (1 << 30);
        final bso = b.sortOrder ?? (1 << 30);
        final cmp = aso.compareTo(bso);
        if (cmp != 0) return cmp;
        return a.localId.compareTo(b.localId);
      }
      // 字母排序。
      if (mode == SortMode.alphabetical) {
        return a.summary.toLowerCase().compareTo(b.summary.toLowerCase());
      }
      // 按截止时间：无截止日期排最后。
      if (mode == SortMode.dueDate) {
        final ad = a.due, bd = b.due;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      }
      // 按编辑时间：最新编辑在前。
      if (mode == SortMode.edited) {
        final ae = a.lastModified ?? a.localModifiedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final be = b.lastModified ?? b.localModifiedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return be.compareTo(ae);
      }
return 0;
    };
  }

  /// 按日历 URL 分组，使用日历显示名称作为分组 key。
  Map<String, List<Task>> _groupByCalendar(
    List<Task> tasks,
    Map<String, String> calendarNames,
  ) {
    final groups = <String, List<Task>>{};
    for (final t in tasks) {
      final name = calendarNames[t.calendarUrl] ?? t.calendarUrl;
      groups.putIfAbsent(name, () => []).add(t);
    }
    final entries = groups.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return Map<String, List<Task>>.fromEntries(entries);
  }
}

/// 将日历颜色 HEX 字符串解析为 Flutter Color。
Color _parseCalendarColor(String hex) {
  try {
    String value = hex.trim();
    if (value.isEmpty) return Colors.grey;
    // 处理 #RGB / #RRGGBB / #AARRGGBB / #RRGGBBAA 等常见格式。
    if (value.startsWith('#')) value = value.substring(1);
    if (value.length == 3) {
      value = value.split('').map((c) => '$c$c').join();
      value = 'ff$value';
    } else if (value.length == 6) {
      value = 'ff$value';
    } else if (value.length == 8) {
      // 假设为 RRGGBBAA，Flutter 需要 AARRGGBB。
      value = value.substring(6, 8) + value.substring(0, 6);
    }
    return Color(int.parse(value, radix: 16));
  } catch (_) {
    return Colors.grey;
  }
}

/// 排序方式下拉菜单。
class _SortModeMenu extends StatelessWidget {
  const _SortModeMenu({
    required this.current,
    required this.onSelected,
  });

  final SortMode current;
  final ValueChanged<SortMode> onSelected;

  String _label(SortMode mode) => switch (mode) {
        SortMode.manual => '手动',
        SortMode.alphabetical => '字母',
        SortMode.dueDate => '截止时间',
        SortMode.edited => '编辑时间',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<SortMode>(
      tooltip: '排序方式',
      initialValue: current,
      onSelected: onSelected,
      itemBuilder: (context) => SortMode.values
          .map((m) => PopupMenuItem(
                value: m,
                child: Text(_label(m)),
              ))
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort, size: 20, color: theme.colorScheme.outline),
            const SizedBox(width: 4),
            Text(
              _label(current),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 隐藏时长下拉菜单。
class _HideHoursMenu extends StatelessWidget {
  const _HideHoursMenu({
    required this.current,
    required this.onSelected,
  });

  final int current;
  final ValueChanged<int> onSelected;

  String _label(int hours) {
    if (hours < 24) return '$hours 小时';
    if (hours == 24) return '1 天';
    if (hours == 24 * 7) return '1 周';
    if (hours == 24 * 30) return '1 月';
    return '$hours 小时';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<int>(
      tooltip: '隐藏已完成时长',
      initialValue: current,
      onSelected: onSelected,
      itemBuilder: (context) => [1, 6, 12, 24, 24 * 7, 24 * 30]
          .map((h) => PopupMenuItem(
                value: h,
                child: Text('隐藏已完成超过 ${_label(h)}'),
              ))
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list, size: 20, color: theme.colorScheme.outline),
            const SizedBox(width: 4),
            Text(
              '隐藏>${_label(current)}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 按清单（日历）过滤下拉菜单。
class _CalendarFilterMenu extends StatelessWidget {
  const _CalendarFilterMenu({
    required this.calendarsAsync,
    required this.selected,
    required this.onSelected,
  });

  final AsyncValue<Map<String, String>> calendarsAsync;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final map = calendarsAsync.valueOrNull ?? {};
    final isAll = selected == null;
    final selectedName = isAll ? null : (map[selected] ?? selected);

    final items = <PopupMenuEntry<String?>>[
      const PopupMenuItem<String?>(
        value: null,
        child: Text('全部清单'),
      ),
      if (map.isNotEmpty) const PopupMenuDivider(),
      ...map.entries.map((e) => PopupMenuItem<String?>(
            value: e.key,
            child: Text(e.value),
          )),
    ];

    return PopupMenuButton<String?>(
      tooltip: '按清单过滤',
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (context) => items,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_outlined,
              size: 20,
              color: isAll
                  ? theme.colorScheme.outline
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              isAll ? '清单' : selectedName!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isAll
                    ? theme.colorScheme.outline
                    : theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 标签快速过滤下拉菜单。
class _TagFilterMenu extends StatelessWidget {
  const _TagFilterMenu({
    required this.tags,
    required this.selectedTag,
    required this.onSelected,
  });

  final Set<String> tags;
  final String? selectedTag;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAll = selectedTag == null || selectedTag == '__all__';
    final items = <PopupMenuEntry<String?>>[
      const PopupMenuItem<String?>(
        value: '__all__',
        child: Text('全部'),
      ),
      if (tags.isNotEmpty) const PopupMenuDivider(),
      ...tags.map((tag) => PopupMenuItem<String?>(
            value: tag,
            child: Text(tag),
          )),
    ];

    return PopupMenuButton<String?>(
      tooltip: '按标签过滤',
      initialValue: isAll ? '__all__' : selectedTag,
      onSelected: onSelected,
      itemBuilder: (context) => items,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.label_outline,
              size: 20,
              color: isAll ? theme.colorScheme.outline : theme.colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              isAll ? '标签' : selectedTag!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isAll ? theme.colorScheme.outline : theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 同步按钮：未同步数据时高亮，并显示角标。
class _SyncButton extends StatelessWidget {
  const _SyncButton({
    required this.running,
    required this.pendingCount,
    required this.onPressed,
  });

  final bool running;
  final int pendingCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasPending = pendingCount > 0;
    final color = hasPending ? scheme.primary : scheme.outline;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: hasPending ? '同步（$pendingCount 项待同步）' : '同步',
          icon: running
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              : Icon(Icons.sync, color: color),
          onPressed: running ? null : onPressed,
        ),
        if (hasPending && !running)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 14),
              decoration: BoxDecoration(
                color: scheme.error,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                pendingCount > 99 ? '99+' : '$pendingCount',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onError,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 当前任务列表主体，按日历分组管理展开/折叠状态。
class _CurrentTaskList extends ConsumerStatefulWidget {
  const _CurrentTaskList({
    required this.groups,
    required this.calendarColors,
    required this.debugSortOrder,
    required this.orphanMode,
    required this.allTasks,
    this.isWide = false,
  });

  final Map<String, List<Task>> groups;
  final Map<String, Color> calendarColors;
  final bool debugSortOrder;
  final OrphanDisplayMode orphanMode;
  final List<Task> allTasks;
  final bool isWide;

  @override
  ConsumerState<_CurrentTaskList> createState() => _CurrentTaskListState();
}

class _CurrentTaskListState extends ConsumerState<_CurrentTaskList> {
  final Set<String> _expanded = {};
  final ScrollController _scrollCtrl = ScrollController();

  /// 鼠标滚轮加速倍率（桌面端默认滚动太慢）。
  static const double _scrollSpeedup = 3.0;

  @override
  void initState() {
    super.initState();
    // 默认展开整棵树。
    for (final tasks in widget.groups.values) {
      _expandAll(tasks);
    }
  }

  @override
  void didUpdateWidget(covariant _CurrentTaskList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 数据刷新后保持新节点展开。
    for (final tasks in widget.groups.values) {
      _expandAll(tasks);
    }
  }

  /// 递归展开所有有子任务的节点。
  void _expandAll(List<Task> tasks) {
    final tree = _WorkTaskTree(tasks);
    void expand(List<Task> nodes) {
      for (final t in nodes) {
        final children = tree.childrenOf(t.uid);
        if (children.isNotEmpty) {
          _expanded.add(t.uid);
          expand(children);
        }
      }
    }

    expand(tree.roots);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entries = widget.groups.entries.toList();

    // 用 Listener 拦截鼠标滚轮事件并加速滚动。
    return Listener(
      onPointerSignal: (signal) {
        if (signal is PointerScrollEvent && _scrollCtrl.hasClients) {
          // 注册到 PointerSignalResolver，阻止 Scrollable 默认处理
          GestureBinding.instance.pointerSignalResolver.register(
            signal,
            (event) {
              if (event is PointerScrollEvent && _scrollCtrl.hasClients) {
                final pos = _scrollCtrl.position;
                final newOffset = (pos.pixels +
                        event.scrollDelta.dy * _scrollSpeedup)
                    .clamp(pos.minScrollExtent, pos.maxScrollExtent);
                pos.jumpTo(newOffset);
              }
            },
          );
        }
      },
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0).copyWith(bottom: 24),
        itemCount: entries.length,
        itemBuilder: (context, index) {
        final category = entries[index].key;
        final tasks = entries[index].value;
        final firstUrl = tasks.firstOrNull?.calendarUrl;
        final calendarColor = firstUrl != null
            ? widget.calendarColors[firstUrl] ?? Colors.grey
            : Colors.grey;
        final tree = _WorkTaskTree(tasks, allTasks: widget.allTasks);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: calendarColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    category,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (widget.debugSortOrder && firstUrl != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '[${widget.calendarColors.length} calendars]',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ...tree.roots.map((root) => _buildNode(tree, root, depth: 0)),
          ],
        );
      },
      ),
    );
  }

  Widget _buildNode(_WorkTaskTree tree, Task task, {required int depth}) {
    final children = tree.childrenOf(task.uid);
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expanded.contains(task.uid);
    final parentPath = tree.parentPathOf(task.uid);
    final selectedTaskId = ref.watch(selectedTaskIdProvider);
    final isSelected = selectedTaskId == task.localId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WorkTaskTile(
          task: task,
          depth: depth,
          hasChildren: hasChildren,
          isExpanded: isExpanded,
          childCount: children.length,
          debugSortOrder: widget.debugSortOrder,
          parentPath: parentPath,
          isWide: widget.isWide,
          selected: isSelected,
          onToggle: hasChildren
              ? () => setState(() {
                    if (isExpanded) {
                      _expanded.remove(task.uid);
                    } else {
                      _expanded.add(task.uid);
                    }
                  })
              : null,
        ),
        if (hasChildren && isExpanded)
          ...children.map((child) => _buildNode(tree, child, depth: depth + 1)),
      ],
    );
  }
}

/// 简易任务树，按 parentUid 分组。
///
/// 当 [allTasks] 提供时，孤儿子任务（父任务不在当前列表中）会计算父路径前缀，
/// 供前缀模式在标题前显示父路径关系。
class _WorkTaskTree {
  _WorkTaskTree(List<Task> tasks, {List<Task> allTasks = const []}) {
    final uids = <String>{};
    for (final t in tasks) {
      uids.add(t.uid);
    }
    final allUidToTask = <String, Task>{
      for (final t in allTasks) t.uid: t,
    };
    for (final t in tasks) {
      final p = t.parentUid;
      final isOrphan = p == null || p.isEmpty || !uids.contains(p);
      if (isOrphan) {
        _roots.add(t);
        // 孤儿子任务：若 allTasks 中能找到父链，构建父路径前缀。
        if (p != null && p.isNotEmpty && !uids.contains(p) && allUidToTask.containsKey(p)) {
          _parentPaths[t.uid] = _buildPath(p, allUidToTask);
        }
      } else {
        _children.putIfAbsent(p, () => []).add(t);
      }
    }
  }

  final List<Task> _roots = [];
  final Map<String, List<Task>> _children = {};
  final Map<String, String> _parentPaths = {};

  List<Task> get roots => _roots;
  List<Task> childrenOf(String parentUid) => _children[parentUid] ?? const [];
  String? parentPathOf(String uid) => _parentPaths[uid];

  /// 从 [uid] 开始向上构建父路径，如 "父任务 › 子任务"。
  static String _buildPath(String uid, Map<String, Task> allTasks) {
    final parts = <String>[];
    String? current = uid;
    while (current != null && allTasks.containsKey(current)) {
      final t = allTasks[current]!;
      parts.add(t.summary);
      current = t.parentUid;
    }
    return parts.reversed.join(' › ');
  }
}

/// 单个工作任务条目。
class _WorkTaskTile extends ConsumerStatefulWidget {
  const _WorkTaskTile({
    required this.task,
    required this.depth,
    required this.hasChildren,
    required this.isExpanded,
    required this.childCount,
    required this.debugSortOrder,
    this.parentPath,
    this.onToggle,
    this.isWide = false,
    this.selected = false,
  });

  final Task task;
  final int depth;
  final bool hasChildren;
  final bool isExpanded;
  final int childCount;
  final bool debugSortOrder;
  /// 前缀模式下孤儿子任务的父路径前缀（如 "父任务 › 子任务"），null 表示无前缀。
  final String? parentPath;
  final VoidCallback? onToggle;
  final bool isWide;
  final bool selected;

  @override
  ConsumerState<_WorkTaskTile> createState() => _WorkTaskTileState();
}

class _WorkTaskTileState extends ConsumerState<_WorkTaskTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fmt = DateFormat('MM/dd');
    final hasNote = widget.task.description.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.only(left: widget.depth * 32.0),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: InkWell(
          onTap: () => _showDetail(context),
          child: Container(
            decoration: BoxDecoration(
              color: widget.selected
                  ? scheme.primaryContainer.withValues(alpha: 0.35)
                  : (_hovering
                      ? scheme.surfaceContainerHighest.withValues(alpha: 0.25)
                      : Colors.white),
              border: widget.selected
                  ? Border(
                      left: BorderSide(
                          color: scheme.primary, width: 3),
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  // 向左下角投影，效果细微
                  offset: const Offset(-1.5, 1.5),
                  blurRadius: 2,
                  spreadRadius: 0,
                  color: Colors.black.withValues(alpha: 0.04),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 展开指示器：使用 GestureDetector 拦截点击，避免触发外层 InkWell
                      if (widget.hasChildren)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: widget.onToggle,
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: Icon(
                              widget.isExpanded
                                  ? Icons.expand_more
                                  : Icons.chevron_right,
                              size: 18,
                              color: scheme.outlineVariant,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 28),
                      const SizedBox(width: 4),
                      // 标题与备注图标
                      Expanded(
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 前缀模式：孤儿任务的父路径前缀。
                          if (widget.parentPath != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                '↳ ${widget.parentPath}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.outline,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.task.summary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    decoration: widget.task.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: widget.task.isCompleted
                                        ? scheme.outline
                                        : scheme.onSurface,
                                  ),
                                ),
                              ),
                              // 状态图标（非"需要操作"时显示）
                              if (widget.task.status != TaskStatus.needsAction)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Tooltip(
                                    message: _statusLabel(widget.task.status),
                                    child: Icon(
                                      _statusIcon(widget.task.status),
                                      size: 14,
                                      color: _statusColor(
                                          widget.task.status, scheme),
                                    ),
                                  ),
                                ),
                              // 完成度（0~100 之间显示）
                              if (widget.task.percent > 0 &&
                                  widget.task.percent < 100)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Text(
                                    '${widget.task.percent}%',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.outline,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ],
                                    ),
                                  ),
                                ),
                              // 描述图标
                              if (hasNote)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.description_outlined,
                                    size: 14,
                                    color: scheme.outline,
                                  ),
                                ),
                              if (widget.debugSortOrder)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Text(
                                    '[so:${widget.task.sortOrder ?? "null"}]',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.primary,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 标签
                    ...widget.task.categories.map(
                      (tag) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _TagChip(label: tag),
                      ),
                    ),
                    // 日期
                    if (widget.task.due != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          fmt.format(widget.task.due!.toLocal()),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: widget.task.isOverdue
                                ? scheme.error
                                : scheme.outline,
                          ),
                        ),
                      ),
                    // 完成按钮：默认显示（淡化），悬停或已完成时正常显示
                    Opacity(
                      opacity:
                          (_hovering || widget.task.isCompleted) ? 1.0 : 0.4,
                      child: _IconButton(
                        icon: widget.task.isCompleted
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: widget.task.isCompleted
                            ? scheme.primary
                            : scheme.outlineVariant,
                        onPressed: () => _toggleCompletion(ref),
                      ),
                    ),
                    const SizedBox(width: 5),
                    // 优先级：点击弹出选择菜单（替换原星标位置）
                    PopupMenuButton<TaskPriority>(
                      onSelected: (p) => _setPriority(ref, p),
                      padding: EdgeInsets.zero,
                      tooltip: '优先级：${_priorityLabel(widget.task.priority)}',
                      itemBuilder: (ctx) => TaskPriority.values.map((p) {
                        final cs = Theme.of(ctx).colorScheme;
                        return PopupMenuItem<TaskPriority>(
                          value: p,
                          child: Row(
                            children: [
                              Icon(Icons.flag_outlined,
                                  size: 16, color: _priorityColor(p)),
                              const SizedBox(width: 6),
                              Text(_priorityLabel(p)),
                              if (p == widget.task.priority)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Icon(Icons.check,
                                      size: 14, color: cs.primary),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: Icon(
                          Icons.flag_outlined,
                          size: 20,
                          color: widget.task.priority == TaskPriority.none
                              ? scheme.outlineVariant
                              : _priorityColor(widget.task.priority),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                indent: 0,
                endIndent: 0,
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  /// 切换任务完成状态。
  Future<void> _toggleCompletion(WidgetRef ref) async {
    final value = !widget.task.isCompleted;
    final repo = ref.read(taskRepositoryProvider);
    final now = DateTime.now().toUtc();
    final updated = widget.task.copyWith(
      status: value ? TaskStatus.completed : TaskStatus.needsAction,
      percent: value ? 100 : 0,
      completed: value ? now : null,
      lastModified: now,
      localModifiedAt: now,
      dirty: true,
    );
    try {
      await repo.update(updated);
    } catch (e) {
      if (ref.context.mounted) {
        ScaffoldMessenger.of(ref.context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
    }
  }

  /// 设置任务优先级（持久化）。
  Future<void> _setPriority(WidgetRef ref, TaskPriority p) async {
    if (p == widget.task.priority) return;
    final repo = ref.read(taskRepositoryProvider);
    final now = DateTime.now().toUtc();
    final updated = widget.task.copyWith(
      priority: p,
      lastModified: now,
      localModifiedAt: now,
      dirty: true,
    );
    try {
      await repo.update(updated);
    } catch (e) {
      if (ref.context.mounted) {
        ScaffoldMessenger.of(ref.context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
    }
  }

  /// 跳转到任务详情页。宽屏下选中任务在侧栏展示，窄屏下推送全页详情。
  void _showDetail(BuildContext context) {
    if (widget.isWide) {
      ref.read(selectedTaskIdProvider.notifier).state = widget.task.localId;
    } else {
      context.push('/tasks/${widget.task.localId}');
    }
  }
}

/// 标签胶囊（如“督办”）。
class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 紧凑型图标按钮。
class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: color,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
      ),
    );
  }
}

/// 宽屏主体：列表 + 可收缩详情侧栏。
///
/// 侧栏默认隐藏，选中任务后从右侧滑入展开，关闭后向右收缩。
/// 切换不同任务时直接替换内容（不重新触发动画）。
class _WideScreenBody extends StatefulWidget {
  const _WideScreenBody({
    required this.listWidget,
    required this.selectedTaskId,
    required this.onClosePanel,
  });

  final Widget listWidget;
  final int? selectedTaskId;
  final VoidCallback onClosePanel;

  @override
  State<_WideScreenBody> createState() => _WideScreenBodyState();
}

class _WideScreenBodyState extends State<_WideScreenBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  /// 当前侧栏中显示的任务 ID（动画期间保持，避免内容在收缩中途消失）。
  int? _displayedTaskId;

  /// 侧栏总宽度（420 内容 + 1 分隔线）。
  static const _panelWidth = 421.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
      value: widget.selectedTaskId != null ? 1.0 : 0.0,
    );
    _displayedTaskId = widget.selectedTaskId;
  }

  @override
  void didUpdateWidget(_WideScreenBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTaskId != oldWidget.selectedTaskId) {
      if (widget.selectedTaskId != null) {
        // 选中新任务：立即更新内容，若侧栏未展开则展开
        _displayedTaskId = widget.selectedTaskId;
        if (_controller.value < 1.0) {
          _controller.forward();
        }
      } else {
        // 关闭侧栏：先收缩，动画结束后清除内容
        _controller.reverse().then((_) {
          if (mounted && widget.selectedTaskId == null) {
            setState(() => _displayedTaskId = null);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: widget.listWidget),
        if (_displayedTaskId != null)
          SizeTransition(
            axis: Axis.horizontal,
            axisAlignment: 1.0,
            sizeFactor: _controller,
            child: SizedBox(
              width: _panelWidth,
              child: Row(
                children: [
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: TaskDetailPanel(
                      taskId: _displayedTaskId!,
                      onClose: widget.onClosePanel,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 空状态组件。
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

// ==================== 任务条信息图标辅助函数 ====================

String _statusLabel(TaskStatus s) => switch (s) {
      TaskStatus.needsAction => '需要操作',
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

Color _statusColor(TaskStatus s, ColorScheme scheme) => switch (s) {
      TaskStatus.needsAction => scheme.outline,
      TaskStatus.inProcess => scheme.secondary,
      TaskStatus.completed => scheme.primary,
      TaskStatus.cancelled => scheme.outline,
    };

Color _priorityColor(TaskPriority p) => switch (p) {
      TaskPriority.none => Colors.grey,
      TaskPriority.high => Colors.red,
      TaskPriority.medium => Colors.orange,
      TaskPriority.low => Colors.blue,
    };
