import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
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

/// 已完成任务的显示范围（默认不显示）。
enum _CompletedRange {
  off, // 不显示已完成
  day1, // 1 天
  day3, // 3 天
  day7, // 7 天
  month1, // 1 月
  year1, // 1 年
  currentYear, // 当年
}

final _completedRangeProvider =
    StateProvider<_CompletedRange>((ref) => _CompletedRange.off);

/// 任务页面专用排序方式（默认手动排序，同步 Nextcloud sortOrder）。
final _currentSortModeProvider = StateProvider<SortMode>((ref) => SortMode.manual);

/// 任务视图模式：当前（关注）/ 全部 / 完成。
enum _TaskViewMode {
  /// 重要：设置了优先级的、或截止日期在当前及之前的所有任务
  important,
  /// 当前：截止日期在配置天数内、或设了优先级、或进行中的任务
  current,
  /// 全部：所有任务（根据开关决定是否显示已完成）
  all,
  /// 完成：包含所有任务（含已完成）
  completed,
}

/// 任务页视图模式。
final _taskViewModeProvider =
    StateProvider<_TaskViewMode>((ref) => _TaskViewMode.current);

/// "当前"视图的时间范围（天）：截止日期在未来多少天内的任务会被纳入。
final _currentViewDaysProvider = StateProvider<int>((ref) => 7);

/// 是否显示任务条扩展属性行（创建/修改/完成时间等）。
final _showExtendedAttrProvider = StateProvider<bool>((ref) => false);

/// 三点菜单项枚举
enum _OptionMenu {
  showExtendedAttr,
  currentViewDays,
  completedRange,
}

/// 任务页配置是否已从 SharedPreferences 加载（防止重复初始化）。
bool _taskPageSettingsLoaded = false;

/// 日历 URL 到显示名称的映射（响应式，跟随 calendarListProvider 自动更新）。
final _calendarNameMapProvider = Provider<Map<String, String>>((ref) {
  final calendars = ref.watch(calendarListProvider).valueOrNull ?? const [];
  return {for (final c in calendars) c.url: c.displayName};
});

/// 已启用同步的日历列表（含名称与颜色），用于清单过滤菜单。
/// 响应式：日历启停或颜色变更时自动刷新。
final _syncedCalendarListProvider =
    Provider<List<({String url, String name, Color color})>>((ref) {
  final calendars = ref.watch(calendarListProvider).valueOrNull ?? const [];
  return [
    for (final c in calendars)
      if (c.syncEnabled)
        (
          url: c.url,
          name: c.displayName,
          color: _parseCalendarColor(c.color),
        ),
  ];
});

/// 日历 URL 到颜色的映射（响应式，跟随 calendarListProvider 自动更新）。
final _calendarColorMapProvider = Provider<Map<String, Color>>((ref) {
  final calendars = ref.watch(calendarListProvider).valueOrNull ?? const [];
  return {
    for (final c in calendars) c.url: _parseCalendarColor(c.color),
  };
});

/// 当前选中的标签过滤（'__all__' 表示不过滤）。
final _selectedTagProvider = StateProvider<String?>((ref) => '__all__');

/// 当前选中的清单过滤（null 表示不过滤）。
final _selectedCalendarProvider = StateProvider<String?>((ref) => null);

/// 当前过滤条件下可用的标签集合（派生自任务列表，自动重算）。
final _availableTagsProvider = Provider<Set<String>>((ref) {
  final tasksAsync = ref.watch(taskListProvider);
  final completedRange = ref.watch(_completedRangeProvider);
  final tasks = tasksAsync.valueOrNull ?? const <Task>[];
  final tags = <String>{};
  for (final t in tasks) {
    if (t.deleted) continue;
    if (completedRange == _CompletedRange.off && t.isCompleted) continue;
    tags.addAll(t.categories);
  }
  return tags;
});

/// 任务列表页，按日历分组展示。
///
/// 采用扁平化条目设计：白色背景、默认全部展开、悬停显示完成按钮、
/// 右侧标签/日期/更多/星标，贴合政务办公类任务清单风格。
class TaskPage extends ConsumerWidget {
  const TaskPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskListProvider);
    final calendarNames = ref.watch(_calendarNameMapProvider);
    final calendarColors = ref.watch(_calendarColorMapProvider);
    final completedRange = ref.watch(_completedRangeProvider);
    final viewMode = ref.watch(_taskViewModeProvider);
    final currentViewDays = ref.watch(_currentViewDaysProvider);
    final sortMode = ref.watch(_currentSortModeProvider);
    final selectedTag = ref.watch(_selectedTagProvider);
    final selectedCalendar = ref.watch(_selectedCalendarProvider);
    final availableTags = ref.watch(_availableTagsProvider);
    final showExtendedAttr = ref.watch(_showExtendedAttrProvider);
    final orphanMode = ref.watch(orphanDisplayModeProvider);
    final syncState = ref.watch(syncControllerProvider);
    final pendingCount = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final isWide = MediaQuery.of(context).size.width > _wideScreenThreshold;
    final selectedTaskId = ref.watch(selectedTaskIdProvider);

    // 从 SharedPreferences 加载已保存的配置并设置自动保存监听
    final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;

    // 首次加载时恢复已保存的配置（延迟到帧结束后执行，避免在 build 中修改 provider）
    if (prefs != null && !_taskPageSettingsLoaded) {
      _taskPageSettingsLoaded = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        final vmIdx = prefs.getInt('task_viewMode');
        if (vmIdx != null && vmIdx < _TaskViewMode.values.length) {
          ref.read(_taskViewModeProvider.notifier).state =
              _TaskViewMode.values[vmIdx];
        }
        final smIdx = prefs.getInt('task_sortMode');
        if (smIdx != null && smIdx < SortMode.values.length) {
          ref.read(_currentSortModeProvider.notifier).state =
              SortMode.values[smIdx];
        }
        final cal = prefs.getString('task_selectedCalendar');
        if (cal != null) ref.read(_selectedCalendarProvider.notifier).state = cal;
        final tag = prefs.getString('task_selectedTag');
        if (tag != null) ref.read(_selectedTagProvider.notifier).state = tag;
        final days = prefs.getInt('task_currentViewDays');
        if (days != null) ref.read(_currentViewDaysProvider.notifier).state = days;
        final crIdx = prefs.getInt('task_completedRange');
        if (crIdx != null && crIdx < _CompletedRange.values.length) {
          ref.read(_completedRangeProvider.notifier).state =
              _CompletedRange.values[crIdx];
        }
        final showAttr = prefs.getBool('task_showExtendedAttr');
        if (showAttr != null) {
          ref.read(_showExtendedAttrProvider.notifier).state = showAttr;
        }
      });
    }

    // 自动保存监听（始终注册，prefs 为 null 时跳过）
    ref.listen(_taskViewModeProvider,
        (_, v) => prefs?.setInt('task_viewMode', v.index));
    ref.listen(_currentSortModeProvider,
        (_, v) => prefs?.setInt('task_sortMode', v.index));
    ref.listen(_selectedCalendarProvider, (_, v) {
      if (v != null) {
        prefs?.setString('task_selectedCalendar', v);
      } else {
        prefs?.remove('task_selectedCalendar');
      }
    });
    ref.listen(_selectedTagProvider, (_, v) {
      if (v != null) {
        prefs?.setString('task_selectedTag', v);
      } else {
        prefs?.remove('task_selectedTag');
      }
    });
    ref.listen(_currentViewDaysProvider,
        (_, v) => prefs?.setInt('task_currentViewDays', v));
    ref.listen(_completedRangeProvider,
        (_, v) => prefs?.setInt('task_completedRange', v.index));
    ref.listen(_showExtendedAttrProvider,
        (_, v) => prefs?.setBool('task_showExtendedAttr', v));

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
      final calendarNames = ref.read(_calendarNameMapProvider);
      final calendarColors = ref.read(_calendarColorMapProvider);
      final completedRangeNow = ref.read(_completedRangeProvider);
      final viewModeNow = ref.read(_taskViewModeProvider);
      final currentViewDaysNow = ref.read(_currentViewDaysProvider);
      final sortModeNow = ref.read(_currentSortModeProvider);
      final selectedTagNow = ref.read(_selectedTagProvider);
      final orphanModeNow = ref.read(orphanDisplayModeProvider);

      final visibleTasks = _applyViewFilters(tasks,
          completedRange: completedRangeNow,
          viewMode: viewModeNow,
          currentViewDays: currentViewDaysNow);
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
            '任务清单_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

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
            SnackBar(
              content: Text('已保存：$savePath'),
              duration: const Duration(seconds: 10),
              action: SnackBarAction(
                label: '打开',
                onPressed: () {
                  if (Platform.isWindows) {
                    Process.run('cmd', ['/c', 'start', '', savePath!]);
                  } else if (Platform.isMacOS) {
                    Process.run('open', [savePath!]);
                  } else {
                    Process.run('xdg-open', [savePath!]);
                  }
                },
              ),
            ),
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
              Icons.checklist_outlined,
              size: 32,
            ),
            SizedBox(width: 10),
            Text('任务'),
          ],
        ),
        actions: [
          // 视图切换：当前 / 全部 / 完成
          _ViewModeSwitch(
            current: viewMode,
            onSelected: (m) =>
                ref.read(_taskViewModeProvider.notifier).state = m,
          ),
          // 按清单过滤（仅显示已启用同步的清单）
          _CalendarFilterMenu(
            syncedCalendars: ref.watch(_syncedCalendarListProvider),
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
          // 更多选项：显示扩展属性、当前视图时间范围、显示完成的任务
          Builder(builder: (buttonContext) {
            return PopupMenuButton<_OptionMenu>(
              tooltip: '更多选项',
              icon: const Icon(Icons.more_vert),
              onSelected: (item) {
                switch (item) {
                  case _OptionMenu.showExtendedAttr:
                    ref.read(_showExtendedAttrProvider.notifier).state =
                        !showExtendedAttr;
                  case _OptionMenu.currentViewDays:
                    _showViewDaysPopup(buttonContext, ref, currentViewDays);
                  case _OptionMenu.completedRange:
                    _showCompletedRangePopup(buttonContext, ref, completedRange);
                }
              },
              itemBuilder: (ctx) => [
                CheckedPopupMenuItem<_OptionMenu>(
                  value: _OptionMenu.showExtendedAttr,
                  checked: showExtendedAttr,
                  child: const Text('显示扩展属性'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<_OptionMenu>(
                  value: _OptionMenu.currentViewDays,
                  child: Text('当前视图时间范围…'),
                ),
                const PopupMenuItem<_OptionMenu>(
                  value: _OptionMenu.completedRange,
                  child: Text('显示完成的任务…'),
                ),
              ],
            );
          }),
        ],
      ),
      body: _buildBody(
        context,
        ref,
        tasksAsync: tasksAsync,
        calendarNames: calendarNames,
        calendarColors: calendarColors,
        completedRange: completedRange,
        viewMode: viewMode,
        currentViewDays: currentViewDays,
        sortMode: sortMode,
        selectedTag: selectedTag,
        selectedCalendar: selectedCalendar,
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
    required Map<String, String> calendarNames,
    required Map<String, Color> calendarColors,
    required _CompletedRange completedRange,
    required _TaskViewMode viewMode,
    required int currentViewDays,
    required SortMode sortMode,
    required String? selectedTag,
    required String? selectedCalendar,
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
        var visibleTasks = _applyViewFilters(tasks,
            completedRange: completedRange, viewMode: viewMode, currentViewDays: currentViewDays);
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
            message: '暂没有待办任务',
          );
        }
        return _CurrentTaskList(
          groups: groups,
          calendarColors: calendarColors,
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

  /// 过滤：移除已删除任务，根据时间范围决定是否显示已完成任务。
  List<Task> _applyFilters(List<Task> tasks,
      {required _CompletedRange completedRange}) {
    final now = DateTime.now().toUtc();
    DateTime? cutoff;
    switch (completedRange) {
      case _CompletedRange.off:
        break;
      case _CompletedRange.day1:
        cutoff = now.subtract(const Duration(days: 1));
      case _CompletedRange.day3:
        cutoff = now.subtract(const Duration(days: 3));
      case _CompletedRange.day7:
        cutoff = now.subtract(const Duration(days: 7));
      case _CompletedRange.month1:
        cutoff = now.subtract(const Duration(days: 30));
      case _CompletedRange.year1:
        cutoff = now.subtract(const Duration(days: 365));
      case _CompletedRange.currentYear:
        cutoff = DateTime(now.year, 1, 1).toUtc();
    }
    return tasks.where((t) {
      if (t.deleted) return false;
      if (t.isCompleted) {
        if (completedRange == _CompletedRange.off) return false;
        if (cutoff != null) {
          final completed = t.completed ?? t.lastModified ?? t.created;
          if (completed == null || completed.isBefore(cutoff)) return false;
        }
      }
      return true;
    }).toList();
  }

  /// 按视图模式过滤任务。
  /// - [current]：截止 [currentViewDays] 天内、或设了优先级、或进行中的任务
  /// - [all]：所有任务（根据开关决定是否显示已完成）
  /// - [completed]：包含所有任务（含已完成，仅排除已删除）
  List<Task> _applyViewFilters(
    List<Task> tasks, {
    required _CompletedRange completedRange,
    required _TaskViewMode viewMode,
    required int currentViewDays,
  }) {
    switch (viewMode) {
      case _TaskViewMode.important:
        final base = _applyFilters(tasks, completedRange: completedRange);
        final now = DateTime.now().toUtc();
        final matched = base.where((t) {
          // 设置了优先级
          if (t.priority != TaskPriority.none) return true;
          // 截止日期在当前及之前
          if (t.due != null && !t.due!.isAfter(now)) return true;
          return false;
        }).toList();
        return _withAncestors(matched, allTasks: base);
      case _TaskViewMode.current:
        final base = _applyFilters(tasks, completedRange: completedRange);
        final now = DateTime.now().toUtc();
        final dueCutoff = now.add(Duration(days: currentViewDays));
        final matched = base.where((t) {
          // 截止日期在配置天数内
          if (t.due != null && t.due!.isBefore(dueCutoff)) return true;
          // 设置了优先级
          if (t.priority != TaskPriority.none) return true;
          // 状态为进行中
          if (t.status == TaskStatus.inProcess) return true;
          return false;
        }).toList();
        // 符合条件任务的父任务链一并显示
        return _withAncestors(matched, allTasks: base);
      case _TaskViewMode.all:
        return _applyFilters(tasks, completedRange: completedRange);
      case _TaskViewMode.completed:
        return tasks.where((t) => !t.deleted).toList();
    }
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

/// 视图模式切换：当前 / 全部 / 完成。
class _ViewModeSwitch extends StatelessWidget {
  const _ViewModeSwitch({
    required this.current,
    required this.onSelected,
  });

  final _TaskViewMode current;
  final ValueChanged<_TaskViewMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PopupMenuButton<_TaskViewMode>(
      tooltip: '视图模式',
      onSelected: onSelected,
      initialValue: current,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon(current),
              size: 18,
              color: scheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              _label(current),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => _TaskViewMode.values.map((m) {
        return PopupMenuItem<_TaskViewMode>(
          value: m,
          child: Row(
            children: [
              Icon(_icon(m), size: 16, color: scheme.outline),
              const SizedBox(width: 8),
              Text(_label(m)),
              if (m == current)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.check, size: 14, color: scheme.primary),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static IconData _icon(_TaskViewMode m) => switch (m) {
        _TaskViewMode.important => Icons.star_outlined,
        _TaskViewMode.current => Icons.inbox_outlined,
        _TaskViewMode.all => Icons.list_outlined,
        _TaskViewMode.completed => Icons.task_alt,
      };

  static String _label(_TaskViewMode m) => switch (m) {
        _TaskViewMode.important => '重要',
        _TaskViewMode.current => '当前',
        _TaskViewMode.all => '全部',
        _TaskViewMode.completed => '完成',
      };
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
/// 弹出"当前视图时间范围"子菜单
void _showViewDaysPopup(
    BuildContext context, WidgetRef ref, int current) {
  final theme = Theme.of(context);
  const options = [1, 3, 7, 14, 30, 90];
  String label(int d) {
    if (d == 1) return '1 天';
    if (d == 7) return '1 周';
    if (d == 30) return '1 月';
    if (d == 90) return '3 月';
    return '$d 天';
  }

  final RenderBox button = context.findRenderObject() as RenderBox;
  final RenderBox overlay =
      Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
  final RelativeRect position = RelativeRect.fromRect(
    Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(button.size.bottomRight(Offset.zero),
          ancestor: overlay),
    ),
    Offset.zero & overlay.size,
  );

  showMenu<int>(
    context: context,
    position: position,
    initialValue: current,
    items: options
        .map((d) => PopupMenuItem(
              value: d,
              child: Row(
                children: [
                  if (d == current)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.check,
                          size: 14, color: theme.colorScheme.primary),
                    ),
                  Text('截止 ${label(d)} 内'),
                ],
              ),
            ))
        .toList(),
  ).then((d) {
    if (d != null) ref.read(_currentViewDaysProvider.notifier).state = d;
  });
}

/// 弹出"显示完成的任务"时间范围子菜单
void _showCompletedRangePopup(
    BuildContext context, WidgetRef ref, _CompletedRange current) {
  final theme = Theme.of(context);
  const options = _CompletedRange.values;
  String label(_CompletedRange r) {
    switch (r) {
      case _CompletedRange.off:
        return '不显示';
      case _CompletedRange.day1:
        return '1 天';
      case _CompletedRange.day3:
        return '3 天';
      case _CompletedRange.day7:
        return '7 天';
      case _CompletedRange.month1:
        return '1 月';
      case _CompletedRange.year1:
        return '1 年';
      case _CompletedRange.currentYear:
        return '当年';
    }
  }

  final RenderBox button = context.findRenderObject() as RenderBox;
  final RenderBox overlay =
      Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
  final RelativeRect position = RelativeRect.fromRect(
    Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(button.size.bottomRight(Offset.zero),
          ancestor: overlay),
    ),
    Offset.zero & overlay.size,
  );

  showMenu<_CompletedRange>(
    context: context,
    position: position,
    initialValue: current,
    items: options
        .map((r) => PopupMenuItem(
              value: r,
              child: Row(
                children: [
                  if (r == current)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.check,
                          size: 14, color: theme.colorScheme.primary),
                    ),
                  Text(label(r)),
                ],
              ),
            ))
        .toList(),
  ).then((r) {
    if (r != null) ref.read(_completedRangeProvider.notifier).state = r;
  });
}

/// 按清单（日历）过滤下拉菜单，仅显示已启用同步的清单并带颜色圆点。
class _CalendarFilterMenu extends StatelessWidget {
  const _CalendarFilterMenu({
    required this.syncedCalendars,
    required this.selected,
    required this.onSelected,
  });

  final List<({String url, String name, Color color})> syncedCalendars;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = syncedCalendars;
    final isAll = selected == null;
    final selectedCal = isAll
        ? null
        : list.where((c) => c.url == selected).firstOrNull;
    final selectedName = selectedCal?.name;

    final items = <PopupMenuEntry<String?>>[
      const PopupMenuItem<String?>(
        value: null,
        child: Text('全部清单'),
      ),
      if (list.isNotEmpty) const PopupMenuDivider(),
      ...list.map((c) => PopupMenuItem<String?>(
            value: c.url,
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: c.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(c.name),
              ],
            ),
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
            if (!isAll && selectedCal != null)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: selectedCal.color,
                  shape: BoxShape.circle,
                ),
              ),
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
    required this.orphanMode,
    required this.allTasks,
    this.isWide = false,
  });

  final Map<String, List<Task>> groups;
  final Map<String, Color> calendarColors;
  final OrphanDisplayMode orphanMode;
  final List<Task> allTasks;
  final bool isWide;

  @override
  ConsumerState<_CurrentTaskList> createState() => _CurrentTaskListState();
}

class _CurrentTaskListState extends ConsumerState<_CurrentTaskList> {
  final Set<String> _expanded = {};
  final ScrollController _scrollCtrl = ScrollController();

  /// 待删除任务：UID → 倒计时定时器。
  /// 点击删除后保留 7 秒撤销窗口，超时后真正执行删除。
  final Map<String, Timer> _pendingDeletes = {};

  /// 当前在任务栏内联编辑标题的任务 localId（null 表示无内联编辑）。
  int? _editingTitleTaskId;

  /// 鼠标滚轮加速倍率（桌面端默认滚动太慢）。
  static const double _scrollSpeedup = 3.0;

  // ================ 自定义拖拽状态 ================
  /// 是否正在拖拽中。
  bool _isDragging = false;
  /// 正在拖拽的日历分组 key（限制单组内拖动）。
  String? _dragCalendarKey;
  /// 拖拽起始时的扁平列表快照。
  List<_FlatNode>? _dragFlat;
  /// 被拖拽的移动块（任务 + 可见后代）。
  List<_FlatNode>? _dragBlock;
  /// 移动块内所有任务 UID（用于环检测与跳过渲染）。
  Set<String>? _dragBlockUids;
  /// 起手时指针相对块顶部的偏移（用于浮动预览定位）。
  Offset? _dragBlockOffset;
  /// 起手时指针全局 X（深度判定的 0 轴）。
  double? _dragStartGlobalX;
  /// 当前指针全局位置。
  Offset? _dragPointerPos;
  /// 在剩余列表中的插入索引。
  int _dropIndex = -1;
  /// 目标缩进深度。
  int _dropDepth = 0;
  /// 浮动预览 Overlay。
  OverlayEntry? _dragOverlay;
  /// 每个任务 UID 对应的 GlobalKey（用于计算落点位置）。
  final Map<String, GlobalKey> _tileKeys = {};

  // ================ 拖拽时的自动滚动 ================
  /// ListView 视口的 GlobalKey（用于获取视口全局边界，触发边缘自动滚动）。
  final GlobalKey _scrollViewportKey = GlobalKey();
  /// 自动滚动定时器：指针停留在视口顶/底边缘时按帧滚动列表。
  Timer? _autoScrollTimer;
  /// 自动滚动方向：-1 向上、1 向下、0 不滚。
  double _autoScrollDir = 0;
  /// 触发自动滚动的边缘距离（指针距视口顶/底多少像素内开始滚）。
  static const double _autoScrollEdge = 64.0;
  /// 每帧自动滚动像素数。
  static const double _autoScrollSpeed = 8.0;

  // ================ 乐观更新（落点即生效，避免刷新回退闪烁） ================
  /// 退出中任务：因编辑导致不再满足过滤条件，临时保留做高亮渐隐动画。
  final Map<String, _ExitingTaskInfo> _exitingTasks = {};

  /// 乐观覆盖的扁平列表（落点后立即显示的目标位置/深度）。
  List<_FlatNode>? _optimisticFlat;
  /// 乐观覆盖对应的日历分组 key。
  String? _optimisticCategory;
  /// 被乐观移动的任务 UID（用于检测 provider 是否已追上）。
  String? _optimisticMovedUid;
  /// 乐观清除的兜底定时器。
  Timer? _optimisticFallbackTimer;

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
    // 仅展开"新出现"的父节点：保留用户手动折叠的状态，
    // 同时让同步新增的带子任务节点默认展开。
    // 注意：点击其他任务条、拖拽落点等触发的重建不应改变展开状态。
    final oldUids = <String>{};
    for (final tasks in oldWidget.groups.values) {
      for (final t in tasks) {
        oldUids.add(t.uid);
      }
    }
    for (final tasks in widget.groups.values) {
      final tree = _WorkTaskTree(tasks);
      void expandNew(List<Task> nodes) {
        for (final t in nodes) {
          final children = tree.childrenOf(t.uid);
          if (children.isNotEmpty) {
            if (!oldUids.contains(t.uid)) {
              _expanded.add(t.uid);
            }
            expandNew(children);
          }
        }
      }
      expandNew(tree.roots);
    }
    // 检测因编辑被过滤掉的任务，加入退出动画队列。
    _detectExitingTasks(oldWidget);
    // 检查乐观更新是否已被 provider 完全反映（移动任务落到目标位置与深度）。
    _maybeClearOptimistic();
  }

  /// 检测旧列表中存在但新列表中消失的任务，加入退出动画队列。
  /// 每个退出任务记录其前一个任务的 UID，用于在渲染时确定插入位置。
  void _detectExitingTasks(covariant _CurrentTaskList oldWidget) {
    // 构建旧扁平列表 UID → info 映射，同时记录 prevUid（前一个任务的 UID）
    final oldMap = <String, _ExitingTaskInfo>{};
    for (final entry in oldWidget.groups.entries) {
      final tree =
          _WorkTaskTree(entry.value, allTasks: oldWidget.allTasks);
      final flat = _flattenTree(tree);
      for (var i = 0; i < flat.length; i++) {
        final node = flat[i];
        oldMap[node.task.uid] = _ExitingTaskInfo(
          task: node.task,
          depth: node.depth,
          category: entry.key,
          prevUid: i > 0 ? flat[i - 1].task.uid : null,
        );
      }
    }
    // 构建新 UID 集合
    final newUids = <String>{};
    for (final tasks in widget.groups.values) {
      for (final t in tasks) {
        newUids.add(t.uid);
      }
    }
    // 新出现的任务如果之前在退出队列中，移除（用户撤销了编辑）
    _exitingTasks.removeWhere((uid, _) => newUids.contains(uid));
    // 找出消失的任务（跳过待删除任务，那些有独立的撤销机制）
    for (final entry in oldMap.entries) {
      final uid = entry.key;
      if (!newUids.contains(uid) &&
          !_exitingTasks.containsKey(uid) &&
          !isPendingDelete(uid)) {
        _exitingTasks[uid] = entry.value;
      }
    }
  }

  /// 检测 provider 是否已追上乐观更新：当被移动任务在新数据中的扁平位置与
  /// 深度与乐观覆盖一致时，清除乐观覆盖，交还给真实数据渲染（无缝衔接）。
  void _maybeClearOptimistic() {
    if (_isDragging) return; // 拖拽期间不切换数据源，避免快照失效
    if (_optimisticFlat == null || _optimisticMovedUid == null) return;
    final category = _optimisticCategory;
    if (category == null || !widget.groups.containsKey(category)) return;

    final tasks = widget.groups[category]!;
    final tree = _WorkTaskTree(tasks, allTasks: widget.allTasks);
    final realFlat = _flattenTree(tree);
    final optimIdx =
        _optimisticFlat!.indexWhere((n) => n.task.uid == _optimisticMovedUid);
    final realIdx =
        realFlat.indexWhere((n) => n.task.uid == _optimisticMovedUid);
    if (realIdx < 0 || optimIdx < 0) return;
    // 位置与深度都对齐才认为 provider 已完全追上。
    if (realIdx == optimIdx &&
        realFlat[realIdx].depth == _optimisticFlat![optimIdx].depth) {
      _clearOptimistic();
    }
  }

  /// 清除乐观更新覆盖状态。
  void _clearOptimistic() {
    _optimisticFlat = null;
    _optimisticCategory = null;
    _optimisticMovedUid = null;
    _optimisticFallbackTimer?.cancel();
    _optimisticFallbackTimer = null;
    if (mounted) setState(() {});
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

  /// 判断任务是否处于待删除状态（撤销窗口内）。
  bool isPendingDelete(String uid) => _pendingDeletes.containsKey(uid);

  /// 调度延迟删除：7 秒后真正执行，期间可撤销。
  void scheduleDelete(Task task) {
    _pendingDeletes[task.uid]?.cancel();
    _pendingDeletes[task.uid] = Timer(const Duration(seconds: 7), () async {
      _pendingDeletes.remove(task.uid);
      final repo = ref.read(taskRepositoryProvider);
      try {
        await repo.delete(task.uid);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
      if (mounted) setState(() {});
    });
    setState(() {});
  }

  /// 撤销待删除任务。
  void cancelDelete(String uid) {
    _pendingDeletes[uid]?.cancel();
    _pendingDeletes.remove(uid);
    setState(() {});
  }

  /// 在指定日历下创建新任务（排序最前），激活详情页并进入内联标题编辑。
  Future<void> _createTaskInCalendar(
      String calendarUrl, List<Task> rootSiblings) async {
    final sortOrder = _computeFirstSortOrder(rootSiblings);
    final task = Task.create(
      calendarUrl: calendarUrl,
      summary: '',
    ).copyWith(
      status: TaskStatus.inProcess,
      sortOrder: sortOrder,
    );
    final repo = ref.read(taskRepositoryProvider);
    final created = await repo.create(task);
    if (!mounted) return;
    setState(() => _editingTitleTaskId = created.localId);
    _openDetail(created.localId);
  }

  /// 在指定父任务下创建子任务（排序第一），展开父任务，激活详情页并进入内联标题编辑。
  Future<void> _createSubtask(Task parent, List<Task> childSiblings) async {
    final sortOrder = _computeFirstSortOrder(childSiblings);
    final task = Task.create(
      calendarUrl: parent.calendarUrl,
      summary: '',
      parentUid: parent.uid,
    ).copyWith(
      status: TaskStatus.inProcess,
      sortOrder: sortOrder,
    );
    final repo = ref.read(taskRepositoryProvider);
    final created = await repo.create(task);
    if (!mounted) return;
    // 展开父任务以显示新子任务
    _expanded.add(parent.uid);
    setState(() => _editingTitleTaskId = created.localId);
    _openDetail(created.localId);
  }

  /// 提交内联标题编辑。
  Future<void> _commitInlineTitle(Task task, String title) async {
    setState(() => _editingTitleTaskId = null);
    final finalTitle = title.isEmpty ? '新任务' : title;
    if (finalTitle == task.summary) return;
    final repo = ref.read(taskRepositoryProvider);
    await repo.update(task.copyWith(
      summary: finalTitle,
      lastModified: DateTime.now().toUtc(),
      localModifiedAt: DateTime.now().toUtc(),
      dirty: true,
    ));
  }

  /// 计算排在最前的 sortOrder 值（比所有兄弟的最小值还小 1）。
  int _computeFirstSortOrder(List<Task> siblings) {
    if (siblings.isEmpty) return 0;
    int minSort = 1 << 30;
    for (final t in siblings) {
      final s = t.sortOrder ?? (1 << 30);
      if (s < minSort) minSort = s;
    }
    return minSort - 1;
  }

  /// 打开任务详情：宽屏用侧栏，窄屏用全页。
  void _openDetail(int localId) {
    if (widget.isWide) {
      ref.read(selectedTaskIdProvider.notifier).state = localId;
    } else if (mounted) {
      context.push('/tasks/$localId');
    }
  }

  @override
  void dispose() {
    for (final t in _pendingDeletes.values) {
      t.cancel();
    }
    _pendingDeletes.clear();
    _optimisticFallbackTimer?.cancel();
    _stopAutoScroll();
    _removeDragOverlay();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entries = widget.groups.entries.toList();
    // 手动排序模式下允许拖拽重排
    final canReorder = ref.watch(_currentSortModeProvider) == SortMode.manual;

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
        key: _scrollViewportKey,
        controller: _scrollCtrl,
        // 允许触摸拖拽滚动：任务条的 GestureDetector(supportedDevices) 限制后
        // 手势竞技场能正确区分——任务条 pan 手势在 hit test 中更深，优先获胜。
        // 鼠标滚轮仍由外层 Listener.onPointerSignal 加速处理。
        physics: const ClampingScrollPhysics(),
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
                  if (firstUrl != null) ...[
                    const SizedBox(width: 4),
                    _AddButton(
                      tooltip: '在此清单创建任务',
                      onPressed: () =>
                          _createTaskInCalendar(firstUrl, tree.roots),
                    ),
                  ],
                ],
              ),
            ),
            _buildGroupBody(category, tree, canReorder),
          ],
        );
      },
      ),
    );
  }

  /// 构建退出中任务的条目：只读 `_WorkTaskTile` 包裹在 `_ExitingTaskTile` 中。
  Widget _buildExitingTaskTile(_ExitingTaskInfo info) {
    return _ExitingTaskTile(
      key: ValueKey('exiting-${info.task.uid}'),
      task: info.task,
      depth: info.depth,
      isWide: widget.isWide,
      onComplete: () {
        if (mounted) {
          setState(() {
            _exitingTasks.remove(info.task.uid);
          });
        }
      },
    );
  }

  /// 构建日历分组的任务列表主体。
  ///
  /// 手动排序模式下，将整棵可见树扁平化为单一列表，使用自定义拖拽实现
  /// （Column + GestureDetector + Overlay 浮动预览 + 插入指示器），
  /// 确保界面移动（位置 + 层级）与数据修改同步：
  /// - 拖拽期间实时显示插入指示器（位置 + 深度）
  /// - 落点后立即应用"乐观 flat"，使界面瞬间到达目标状态
  /// - provider 刷新追上后无缝交还给真实数据
  Widget _buildGroupBody(String category, _WorkTaskTree tree, bool canReorder) {
    // 乐观覆盖优先：落点后立即用预算的目标扁平列表渲染。
    final useOptimistic = _optimisticFlat != null &&
        _optimisticCategory == category;
    final flat = useOptimistic ? _optimisticFlat! : _flattenTree(tree);

    // 将退出任务按旧顺序插入到扁平列表中（在原始位置显示高亮渐隐动画）
    final merged = _mergeWithExiting(category, flat);

    if (!canReorder || flat.length < 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in merged)
            if (item is _FlatNode)
              _buildFlatTile(category, flat, tree, item, canReorder: false)
            else if (item is _ExitingTaskInfo)
              _buildExitingTaskTile(item),
        ],
      );
    }

    // 拖拽期间：移动块保留在树中（以半透明"幽灵"形式），避免其
    // GestureDetector 被销毁导致正在进行的拖拽手势中断；落点处插入指示器。
    final isDragGroup = _isDragging &&
        _dragCalendarKey == category &&
        _dragBlockUids != null;
    final blockUids = isDragGroup ? _dragBlockUids! : <String>{};

    final children = <Widget>[];
    int remainingIdx = 0;
    for (final item in merged) {
      if (item is _ExitingTaskInfo) {
        // 退出任务不参与拖拽，直接追加
        children.add(_buildExitingTaskTile(item));
        continue;
      }
      final node = item as _FlatNode;
      final isBlock = blockUids.contains(node.task.uid);

      // 在当前剩余条目前插入指示器（带稳定 key，避免重排时被重建）。
      if (isDragGroup && !isBlock && _dropIndex == remainingIdx) {
        children.add(KeyedSubtree(
          key: const ValueKey('drop-indicator'),
          child: _buildInsertionIndicator(_dropDepth),
        ));
      }
      children.add(_buildFlatTile(category, flat, tree, node,
          canReorder: true, isDragGhost: isBlock && isDragGroup));
      if (!isBlock) remainingIdx++;
    }
    // 插入到末尾。
    if (isDragGroup && _dropIndex == remainingIdx) {
      children.add(KeyedSubtree(
        key: const ValueKey('drop-indicator'),
        child: _buildInsertionIndicator(_dropDepth),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  /// 将退出任务按旧位置插入到新扁平列表中，返回混合列表。
  /// 每个退出任务根据其 prevUid（旧列表中前一个任务的 UID）确定插入位置。
  /// 元素类型为 _FlatNode（常规任务）或 _ExitingTaskInfo（退出任务）。
  List<Object> _mergeWithExiting(String category, List<_FlatNode> flat) {
    final exiting = _exitingTasks.values
        .where((info) => info.category == category)
        .toList();
    if (exiting.isEmpty) return flat;

    // 新扁平列表 UID → 索引
    final newUidToIndex = <String, int>{
      for (var i = 0; i < flat.length; i++) flat[i].task.uid: i,
    };

    // 为每个退出任务计算插入位置：紧跟在 prevUid 对应任务之后
    // 若 prevUid 也被过滤（同样在退出队列），则沿 prevUid 链向前追溯
    final exitingAtPosition = <int, List<_ExitingTaskInfo>>{};
    for (final info in exiting) {
      int insertAt = 0;
      String? prevUid = info.prevUid;
      while (prevUid != null) {
        final prevIdx = newUidToIndex[prevUid];
        if (prevIdx != null) {
          insertAt = prevIdx + 1;
          break;
        }
        // prevUid 的任务也在退出队列，继续向前追溯
        prevUid = _exitingTasks[prevUid]?.prevUid;
      }
      exitingAtPosition.putIfAbsent(insertAt, () => []).add(info);
    }

    // 构建混合列表
    final merged = <Object>[];
    for (var i = 0; i <= flat.length; i++) {
      if (exitingAtPosition.containsKey(i)) {
        for (final info in exitingAtPosition[i]!) {
          merged.add(info);
        }
      }
      if (i < flat.length) {
        merged.add(flat[i]);
      }
    }
    return merged;
  }

  /// 插入指示器：一条按目标深度缩进的彩色细线。
  /// 缩进与任务条内容对齐（条目内部已按 depth*32 缩进，此处同基准）。
  Widget _buildInsertionIndicator(int depth) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(left: depth * 32.0, right: 16),
      child: Container(
        height: 3,
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  /// 将可见树扁平化为列表（仅展开的节点及其子节点）。
  List<_FlatNode> _flattenTree(_WorkTaskTree tree) {
    final result = <_FlatNode>[];
    void walk(Task task, int depth) {
      result.add(_FlatNode(task, depth));
      if (_expanded.contains(task.uid)) {
        for (final child in tree.childrenOf(task.uid)) {
          walk(child, depth + 1);
        }
      }
    }

    for (final root in tree.roots) {
      walk(root, 0);
    }
    return result;
  }

  /// 构建扁平列表中的单个任务条。
  ///
  /// 可重排时为每个条目分配一个 [GlobalKey]（既是稳定标识，又用于拖拽中
  /// 计算落点），并用 [GestureDetector] 包裹以接管平移手势，触发自定义拖拽。
  /// 结构保持恒定（始终 GestureDetector→Opacity→tile），仅在 [isDragGhost]
  /// 时降低透明度，避免幽灵切换导致 widget 重建、拖拽手势中断。
  Widget _buildFlatTile(
    String category,
    List<_FlatNode> flat,
    _WorkTaskTree tree,
    _FlatNode node, {
    bool canReorder = false,
    bool isDragGhost = false,
  }) {
    final task = node.task;
    final depth = node.depth;
    final children = tree.childrenOf(task.uid);
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expanded.contains(task.uid);
    final parentPath = tree.parentPathOf(task.uid);
    final selectedTaskId = ref.watch(selectedTaskIdProvider);
    final isSelected = selectedTaskId == task.localId;
    final pendingDelete = isPendingDelete(task.uid);

    final tile = _WorkTaskTile(
      task: task,
      depth: depth,
      hasChildren: hasChildren,
      isExpanded: isExpanded,
      childCount: children.length,
      parentPath: parentPath,
      isWide: widget.isWide,
      selected: isSelected,
      pendingDelete: pendingDelete,
      editingTitle: _editingTitleTaskId == task.localId,
      onToggle: hasChildren
          ? () => setState(() {
                if (isExpanded) {
                  _expanded.remove(task.uid);
                } else {
                  _expanded.add(task.uid);
                }
              })
          : null,
      onAddSubtask: () => _createSubtask(task, children),
      onDelete: () => scheduleDelete(task),
      onUndoDelete: () => cancelDelete(task.uid),
      onTitleCommitted: (title) => _commitInlineTitle(task, title),
    );

    if (!canReorder) {
      return KeyedSubtree(
        key: ValueKey('node-${task.uid}'),
        child: tile,
      );
    }

    final key =
        _tileKeys.putIfAbsent(task.uid, () => GlobalKey(debugLabel: task.uid));
    // GlobalKey 置于最外层：指示器重排时 Flutter 按 key 匹配并移动该子树，
    // 保留 GestureDetector 状态，使正在进行的拖拽手势不中断。
    // 拖拽期间移动块塌缩为零尺寸（SizedBox.shrink）：剩余条目上移填空隙，
    // 插入指示器能紧跟指针；被拖任务由 Overlay 浮动预览跟随指针呈现。
    return KeyedSubtree(
      key: key,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // 仅接受鼠标输入，避免触控板滚动/平移误触发拖拽
        supportedDevices: const {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
        },
        onPanStart: (d) => _onDragStart(category, flat, node, d),
        onPanUpdate: (d) => _onDragUpdate(d),
        onPanEnd: (d) => _onDragEnd(),
        onPanCancel: () => _onDragCancel(),
        child: isDragGhost ? const SizedBox.shrink() : tile,
      ),
    );
  }

  // ============== 自定义拖拽流程 ==============

  /// 拖拽开始：记录移动块、起手偏移，初始化落点为原位置，显示浮动预览。
  void _onDragStart(
    String category,
    List<_FlatNode> flat,
    _FlatNode node,
    DragStartDetails details,
  ) {
    _dragCalendarKey = category;
    _dragFlat = flat;
    final idx = flat.indexWhere((n) => n.task.uid == node.task.uid);
    if (idx < 0) return;
    final movedDepth = node.depth;

    // 计算移动块：任务 + 可见后代
    int blockEnd = idx + 1;
    while (blockEnd < flat.length && flat[blockEnd].depth > movedDepth) {
      blockEnd++;
    }
    final block = flat.sublist(idx, blockEnd);
    final blockUids = block.map((n) => n.task.uid).toSet();

    // 落点初始化：保持在原位置（剩余列表中的等价索引）。
    int remainingIdx = 0;
    for (int i = 0; i < idx; i++) {
      if (!blockUids.contains(flat[i].task.uid)) remainingIdx++;
    }

    _dragBlock = block;
    _dragBlockUids = blockUids;
    _dragBlockOffset = details.localPosition;
    _dragStartGlobalX = details.globalPosition.dx;
    _dragPointerPos = details.globalPosition;
    _dropIndex = remainingIdx;
    _dropDepth = movedDepth;
    _isDragging = true;

    _showDragOverlay();
    setState(() {});
  }

  /// 拖拽移动：更新指针位置，重算落点（索引 + 深度），并按需触发边缘自动滚动。
  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    _dragPointerPos = details.globalPosition;
    _computeDrop();
    _dragOverlay?.markNeedsBuild();
    _updateAutoScroll(details.globalPosition);
  }

  /// 拖拽结束：执行重排并清理拖拽状态。
  void _onDragEnd() {
    if (!_isDragging) return;
    _performReorder();
    _clearDrag();
  }

  /// 拖拽取消：仅清理状态，不落库。
  void _onDragCancel() {
    _clearDrag();
  }

  /// 清理拖拽即时状态（保留乐观覆盖直到 provider 追上）。
  void _clearDrag() {
    _isDragging = false;
    _dragCalendarKey = null;
    _dragFlat = null;
    _dragBlock = null;
    _dragBlockUids = null;
    _dragBlockOffset = null;
    _dragStartGlobalX = null;
    _dragPointerPos = null;
    _dropIndex = -1;
    _dropDepth = 0;
    _stopAutoScroll();
    _removeDragOverlay();
    if (mounted) setState(() {});
  }

  /// 根据指针在视口内的位置决定是否触发自动滚动：
  /// 指针接近视口顶部时向上滚，接近底部时向下滚，否则停止。
  void _updateAutoScroll(Offset globalPos) {
    final box =
        _scrollViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !_scrollCtrl.hasClients) {
      _autoScrollDir = 0;
      _stopAutoScroll();
      return;
    }
    final viewportTop = box.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + box.size.height;
    if (globalPos.dy < viewportTop + _autoScrollEdge) {
      _autoScrollDir = -1.0;
      _startAutoScroll();
    } else if (globalPos.dy > viewportBottom - _autoScrollEdge) {
      _autoScrollDir = 1.0;
      _startAutoScroll();
    } else {
      _autoScrollDir = 0;
      _stopAutoScroll();
    }
  }

  /// 启动周期定时器按帧滚动列表；已在运行则保持。
  void _startAutoScroll() {
    if (_autoScrollTimer != null && _autoScrollTimer!.isActive) return;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (_autoScrollDir == 0 || !_scrollCtrl.hasClients || !_isDragging) {
        _stopAutoScroll();
        return;
      }
      final pos = _scrollCtrl.position;
      final delta = _autoScrollDir * _autoScrollSpeed;
      final newOffset = (pos.pixels + delta)
          .clamp(pos.minScrollExtent, pos.maxScrollExtent);
      // 已到边界则停止
      if (newOffset == pos.pixels) {
        _stopAutoScroll();
        return;
      }
      pos.jumpTo(newOffset);
      // 列表滚动后重算落点并刷新浮动预览
      _computeDrop();
      _dragOverlay?.markNeedsBuild();
    });
  }

  /// 停止自动滚动定时器。
  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  /// 实时计算落点：基于指针 Y 在剩余条目中确定插入索引，
  /// 基于指针 X 映射到缩进深度（受插入点上下文限制）。
  void _computeDrop() {
    final flat = _dragFlat;
    final blockUids = _dragBlockUids;
    final pos = _dragPointerPos;
    if (flat == null || blockUids == null || pos == null) return;

    // 剩余条目（按可见顺序）
    final remaining = <_FlatNode>[];
    for (final n in flat) {
      if (!blockUids.contains(n.task.uid)) remaining.add(n);
    }

    // 通过各条目 GlobalKey 的中点判定插入索引。
    int dropIdx = remaining.length;
    for (int i = 0; i < remaining.length; i++) {
      final key = _tileKeys[remaining[i].task.uid];
      final ctx = key?.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      final midY = top + box.size.height / 2;
      if (pos.dy < midY) {
        dropIdx = i;
        break;
      }
    }

    // 层级变动范围：插入位置上下任务条层级之间，并允许降到上方任务条的下一级
    // （上方任务的子级，即 upperDepth + 1）。
    final hasUpper = dropIdx > 0;
    final hasLower = dropIdx < remaining.length;
    final upperDepth = hasUpper ? remaining[dropIdx - 1].depth : 0;
    final lowerDepth = hasLower ? remaining[dropIdx].depth : 0;
    int minDepth;
    int maxDepth;
    if (hasUpper && hasLower) {
      // 介于上下任务条层级之间，且可到上方任务条 +1 级（子级）。
      minDepth = upperDepth < lowerDepth ? upperDepth : lowerDepth;
      maxDepth = lowerDepth > upperDepth + 1 ? lowerDepth : upperDepth + 1;
    } else if (hasUpper) {
      minDepth = 0;
      maxDepth = upperDepth + 1;
    } else if (hasLower) {
      minDepth = 0;
      maxDepth = lowerDepth;
    } else {
      minDepth = 0;
      maxDepth = 0;
    }

    // 深度判定：以起手点击 X 为 0 轴，向右加深、向左变浅。
    // 判定宽度增大 50%（48px/级），并设略大于半级的死区抑制抖动。
    final startX = _dragStartGlobalX;
    final initialDepth = _dragBlock?.first.depth ?? 0;
    final baseDepth = initialDepth.clamp(minDepth, maxDepth);
    int depth;
    if (startX == null) {
      depth = baseDepth;
    } else {
      const levelWidth = 48.0;
      const deadZone = levelWidth * 0.6;
      final dx = pos.dx - startX;
      int depthDelta;
      if (dx >= deadZone) {
        depthDelta = ((dx - deadZone) / levelWidth).floor() + 1;
      } else if (dx <= -deadZone) {
        depthDelta = ((dx + deadZone) / levelWidth).ceil() - 1;
      } else {
        depthDelta = 0;
      }
      depth = (baseDepth + depthDelta).clamp(minDepth, maxDepth);
    }

    if (dropIdx != _dropIndex || depth != _dropDepth) {
      setState(() {
        _dropIndex = dropIdx;
        _dropDepth = depth;
      });
    }
  }

  /// 执行重排：依据拖拽期间预算的 [_dropIndex]/[_dropDepth] 修改数据，
  /// 并立即应用"乐观 flat"使界面瞬间到达目标状态。
  Future<void> _performReorder() async {
    final flat = _dragFlat;
    final block = _dragBlock;
    final blockUids = _dragBlockUids;
    if (flat == null || block == null || blockUids == null) return;
    if (_dropIndex < 0) return;
    final category = _dragCalendarKey;
    if (category == null) return;

    final movedTask = block.first.task;
    final oldParentUid = movedTask.parentUid;
    final movedDepth = block.first.depth;

    // 剩余列表
    final remaining = <_FlatNode>[];
    for (final n in flat) {
      if (!blockUids.contains(n.task.uid)) remaining.add(n);
    }
    final insertAt = _dropIndex.clamp(0, remaining.length).toInt();

    // 新父任务（依据剩余列表 + 目标深度）
    final newParentUid =
        _findParentForDepthRemaining(remaining, insertAt, _dropDepth);

    // 环检测：不允许移入自己的后代
    if (newParentUid != null && blockUids.contains(newParentUid)) return;

    // 构建"乐观 flat"：剩余 + 平移后的块（块深度整体偏移到 _dropDepth）。
    final depthDelta = _dropDepth - movedDepth;
    final shiftedBlock =
        block.map((n) => _FlatNode(n.task, n.depth + depthDelta)).toList();
    final optimisticFlat = <_FlatNode>[
      ...remaining.sublist(0, insertAt),
      ...shiftedBlock,
      ...remaining.sublist(insertAt),
    ];

    // 立即应用乐观覆盖（界面瞬间到位）。
    setState(() {
      _optimisticFlat = optimisticFlat;
      _optimisticCategory = category;
      _optimisticMovedUid = movedTask.uid;
      _optimisticFallbackTimer?.cancel();
      _optimisticFallbackTimer = Timer(const Duration(seconds: 2), () {
        // 兜底：provider 长时间未追上时强制清除，避免永久覆盖。
        _clearOptimistic();
      });
    });

    // 同步写入数据库（parentUid + sortOrder）。
    final repo = ref.read(taskRepositoryProvider);
    final now = DateTime.now().toUtc();

    if (newParentUid != oldParentUid) {
      await repo.update(movedTask.copyWith(
        parentUid: newParentUid,
        lastModified: now,
        localModifiedAt: now,
        dirty: true,
      ));
    }

    // 新兄弟组排序值（乐观 flat 中目标父任务下的顺序）
    final newSiblingIds = <int>[];
    for (final node in optimisticFlat) {
      final isMoved = node.task.uid == movedTask.uid;
      final isChildOfNewParent =
          !isMoved && node.task.parentUid == newParentUid;
      if (isMoved || isChildOfNewParent) {
        newSiblingIds.add(node.task.localId);
      }
    }
    if (newSiblingIds.isNotEmpty) {
      await saveSortOrders(ref, newSiblingIds);
    }

    // 父任务变更时，同时刷新原兄弟组的排序值。
    if (newParentUid != oldParentUid) {
      final oldSiblingIds = <int>[];
      for (final node in remaining) {
        if (node.task.parentUid == oldParentUid &&
            node.task.uid != movedTask.uid) {
          oldSiblingIds.add(node.task.localId);
        }
      }
      if (oldSiblingIds.isNotEmpty) {
        await saveSortOrders(ref, oldSiblingIds);
      }
    }

    // 写完后主动检测一次是否已追上（某些情况下 didUpdateWidget 可能先到）。
    if (mounted) _maybeClearOptimistic();
  }

  /// 在剩余列表中按目标深度查找新父任务 UID。
  String? _findParentForDepthRemaining(
    List<_FlatNode> remaining,
    int insertAt,
    int desiredDepth,
  ) {
    if (desiredDepth == 0) return null;
    final targetDepth = desiredDepth - 1;
    for (int i = insertAt - 1; i >= 0; i--) {
      if (remaining[i].depth == targetDepth) {
        return remaining[i].task.uid;
      }
    }
    // 回退：若下一个任务与目标深度相同，复用其父任务
    if (insertAt < remaining.length &&
        remaining[insertAt].depth == desiredDepth) {
      return remaining[insertAt].task.parentUid;
    }
    return null;
  }

  // ============== 浮动预览 Overlay ==============

  void _showDragOverlay() {
    _removeDragOverlay();
    _dragOverlay = OverlayEntry(builder: (ctx) => _buildDragPreview());
    Overlay.of(context).insert(_dragOverlay!);
  }

  void _removeDragOverlay() {
    _dragOverlay?.remove();
    _dragOverlay = null;
  }

  /// 浮动预览：跟随指针的卡片，显示任务标题及子任务数量角标。
  Widget _buildDragPreview() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final block = _dragBlock;
    if (block == null ||
        _dragPointerPos == null ||
        _dragBlockOffset == null) {
      return const SizedBox.shrink();
    }
    final head = block.first.task;
    final blockCount = block.length;
    final mq = MediaQuery.of(context);
    final maxWidth = mq.size.width * 0.6;

    final offsetX = _dragBlockOffset!.dx;
    final offsetY = _dragBlockOffset!.dy;
    final left =
        (_dragPointerPos!.dx - offsetX).clamp(8.0, mq.size.width - maxWidth - 8);
    final top = (_dragPointerPos!.dy - offsetY)
        .clamp(8.0, mq.size.height - 60);

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.7,
          child: Material(
            elevation: 10,
            color: scheme.surface,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.drag_indicator,
                        size: 16, color: scheme.outline),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        head.summary.isEmpty ? '新任务' : head.summary,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (blockCount > 1) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+${blockCount - 1}',
                          style: TextStyle(
                            color: scheme.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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

/// 扁平化节点：任务 + 缩进深度（用于跨层级自定义拖拽的扁平列表）。
class _FlatNode {
  const _FlatNode(this.task, this.depth);
  final Task task;
  final int depth;
}

/// 退出中任务的信息。
class _ExitingTaskInfo {
  const _ExitingTaskInfo({
    required this.task,
    required this.depth,
    required this.category,
    this.prevUid,
  });
  final Task task;
  final int depth;
  final String category;
  /// 旧扁平列表中紧邻此任务之前的任务 UID（用于确定插入位置）。
  final String? prevUid;
}

/// 退出中任务条目：因编辑导致不再满足过滤条件时，
/// 先以琥珀色高亮一段时间，然后渐隐 + 塌缩高度从列表中移除。
class _ExitingTaskTile extends StatefulWidget {
  const _ExitingTaskTile({
    super.key,
    required this.task,
    required this.depth,
    required this.isWide,
    required this.onComplete,
  });
  final Task task;
  final int depth;
  final bool isWide;
  final VoidCallback onComplete;
  @override
  State<_ExitingTaskTile> createState() => _ExitingTaskTileState();
}

class _ExitingTaskTileState extends State<_ExitingTaskTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    // 高亮一段时间后开始渐隐+塌缩
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _ctrl.forward();
    });
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final progress = _ctrl.value; // 0 → 1
          return Align(
            alignment: Alignment.topCenter,
            // heightFactor 从 1.0 → 0.0 实现高度塌缩
            heightFactor: 1.0 - progress,
            child: Opacity(
              opacity: 1.0 - progress,
              child: _WorkTaskTile(
                task: widget.task,
                depth: widget.depth,
                hasChildren: false,
                isExpanded: false,
                childCount: 0,
                isWide: widget.isWide,
                // 高亮背景色直接作用于任务条内部，不覆盖缩进区域
                highlightColor:
                    Colors.amber.withValues(alpha: 0.3 * (1.0 - progress)),
              ),
            ),
          );
        },
      ),
    );
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
    this.parentPath,
    this.onToggle,
    this.isWide = false,
    this.selected = false,
    this.pendingDelete = false,
    this.editingTitle = false,
    this.onAddSubtask,
    this.onDelete,
    this.onUndoDelete,
    this.onTitleCommitted,
    this.highlightColor,
  });

  final Task task;
  final int depth;
  final bool hasChildren;
  final bool isExpanded;
  final int childCount;
  /// 前缀模式下孤儿子任务的父路径前缀（如 "父任务 › 子任务"），null 表示无前缀。
  final String? parentPath;
  final VoidCallback? onToggle;
  final bool isWide;
  final bool selected;
  /// 是否处于待删除状态（撤销窗口内）。
  final bool pendingDelete;
  /// 是否正在内联编辑标题。
  final bool editingTitle;
  /// 点击"添加子任务"回调。
  final VoidCallback? onAddSubtask;
  /// 点击"删除"回调（启动撤销倒计时）。
  final VoidCallback? onDelete;
  /// 点击撤销删除回调。
  final VoidCallback? onUndoDelete;
  /// 内联标题编辑提交回调。
  final ValueChanged<String>? onTitleCommitted;
  /// 高亮背景色（用于退出动画），为 null 时使用默认背景色逻辑。
  final Color? highlightColor;

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
    final fmtAttr = DateFormat('MM-dd HH:mm');
    final hasNote = widget.task.description.trim().isNotEmpty;
    final t = widget.task;
    final showAttr = ref.watch(_showExtendedAttrProvider);
    // 属性行信息：远端创建、远端修改、本地修改、同步状态（null 显示 "-"）
    final attrParts = <String>[
      '远端创建 ${t.created != null ? fmtAttr.format(t.created!.toLocal()) : '-'}',
      '远端修改 ${t.lastModified != null ? fmtAttr.format(t.lastModified!.toLocal()) : '-'}',
      '本地修改 ${t.localModifiedAt != null ? fmtAttr.format(t.localModifiedAt!.toLocal()) : '-'}',
      t.dirty ? '待同步' : '已同步',
    ];

    return Container(
      padding: EdgeInsets.only(left: widget.depth * 32.0),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: InkWell(
          onTap: () => _showDetail(context),
          child: Container(
            decoration: BoxDecoration(
              color: widget.highlightColor ??
                  (widget.pendingDelete
                      ? scheme.errorContainer.withValues(alpha: 0.3)
                      : (widget.selected
                          ? scheme.primaryContainer.withValues(alpha: 0.35)
                          : (_hovering
                              ? scheme.surfaceContainerHighest.withValues(alpha: 0.25)
                              : Colors.white))),
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
                  padding: const EdgeInsets.fromLTRB(4, 5, 8, 5),
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
                                child: widget.editingTitle
                                    ? _InlineTitleEditor(
                                        initialText: widget.task.summary,
                                        onCommitted:
                                            widget.onTitleCommitted ?? (_) {},
                                      )
                                    : Text(
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
                    // 三点菜单 / 撤销删除
                    if (widget.pendingDelete)
                      _IconButton(
                        icon: Icons.undo,
                        color: scheme.primary,
                        onPressed: widget.onUndoDelete,
                      )
                    else
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        tooltip: '更多操作',
                        onSelected: (value) {
                          switch (value) {
                            case 'add_subtask':
                              widget.onAddSubtask?.call();
                              break;
                            case 'delete':
                              widget.onDelete?.call();
                              break;
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem<String>(
                            value: 'add_subtask',
                            child: Row(
                              children: [
                                Icon(Icons.add,
                                    size: 16, color: Theme.of(ctx).colorScheme.primary),
                                const SizedBox(width: 6),
                                const Text('添加子任务'),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline,
                                    size: 16, color: Theme.of(ctx).colorScheme.error),
                                const SizedBox(width: 6),
                                const Text('删除'),
                              ],
                            ),
                          ),
                        ],
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: Icon(
                            Icons.more_horiz,
                            size: 18,
                            color: scheme.outlineVariant,
                          ),
                        ),
                      ),
                    const SizedBox(width: 5),
                    // 优先级：点击切换 高→低→无→高（不弹菜单）
                    Tooltip(
                      message: '优先级：${_priorityLabel(widget.task.priority)}',
                      child: _IconButton(
                        icon: _priorityIcon(widget.task.priority),
                        color: widget.task.priority == TaskPriority.none
                            ? scheme.outlineVariant
                            : _priorityColor(widget.task.priority),
                        onPressed: () => _cyclePriority(ref),
                      ),
                    ),
                  ],
                ),
              ),
              // 属性行：创建、远端修改、本地修改、完成时间
              if (showAttr && attrParts.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 32, right: 8, bottom: 4),
                    child: Text(
                      attrParts.join('  ·  '),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.outlineVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
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

  /// 循环切换优先级：无→高→低→无（跳过中级）。
  Future<void> _cyclePriority(WidgetRef ref) async {
    final next = switch (widget.task.priority) {
      TaskPriority.none => TaskPriority.high,
      TaskPriority.high => TaskPriority.low,
      _ => TaskPriority.none,
    };
    final repo = ref.read(taskRepositoryProvider);
    final now = DateTime.now().toUtc();
    final updated = widget.task.copyWith(
      priority: next,
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
    // 内联编辑标题时不跳转
    if (widget.editingTitle) return;
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
  final VoidCallback? onPressed;
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

/// 清单标题旁的小型"+"创建按钮。
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed, this.tooltip});

  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final btn = InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: scheme.outlineVariant, width: 1),
        ),
        child: Icon(
          Icons.add,
          size: 14,
          color: scheme.outline,
        ),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

/// 任务栏内联标题编辑器：自动聚焦，失焦或回车时提交。
class _InlineTitleEditor extends StatefulWidget {
  const _InlineTitleEditor({
    required this.initialText,
    required this.onCommitted,
  });

  final String initialText;
  final ValueChanged<String> onCommitted;

  @override
  State<_InlineTitleEditor> createState() => _InlineTitleEditorState();
}

class _InlineTitleEditorState extends State<_InlineTitleEditor> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  bool _committed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
    _focus = FocusNode();
    _focus.addListener(_onFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focus.requestFocus();
        _ctrl.selection = TextSelection(
            baseOffset: 0, extentOffset: _ctrl.text.length);
      }
    });
  }

  void _onFocusChange() {
    if (!_focus.hasFocus && !_committed) {
      _commit();
    }
  }

  void _commit() {
    _committed = true;
    widget.onCommitted(_ctrl.text.trim());
  }

  @override
  void dispose() {
    if (!_committed) {
      _commit();
    }
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      maxLines: 1,
      textInputAction: TextInputAction.done,
      onSubmitted: (v) => _commit(),
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        isCollapsed: true,
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
      TaskPriority.medium => Colors.blue,
      TaskPriority.low => Colors.blue,
    };

/// 优先级图标：高=实心星、中/低=空心星、无=空心星（灰色切换按钮）
IconData _priorityIcon(TaskPriority p) =>
    p == TaskPriority.high ? Icons.star : Icons.star_border;
