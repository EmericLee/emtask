import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/providers.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_status.dart';

/// 任务详情弹窗。
///
/// 默认进入查看模式，点击编辑可切换为编辑模式。
/// 保存后调用 [TaskRepository] 更新并关闭弹窗。
class TaskDetailDialog extends ConsumerStatefulWidget {
  const TaskDetailDialog({super.key, required this.task});

  final Task task;

  @override
  ConsumerState<TaskDetailDialog> createState() => _TaskDetailDialogState();
}

class _TaskDetailDialogState extends ConsumerState<TaskDetailDialog> {
  bool _editing = false;

  late final TextEditingController _summaryCtrl;
  late final TextEditingController _descCtrl;
  late DateTime? _due;
  late TaskStatus _status;
  late TaskPriority _priority;
  late int _percent;
  late List<String> _categories;

  @override
  void initState() {
    super.initState();
    _summaryCtrl = TextEditingController(text: widget.task.summary);
    _descCtrl = TextEditingController(text: widget.task.description);
    _due = widget.task.due;
    _status = widget.task.status;
    _priority = widget.task.priority;
    _percent = widget.task.percent;
    _categories = List.of(widget.task.categories);
  }

  @override
  void dispose() {
    _summaryCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_summaryCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入任务标题')),
      );
      return;
    }
    final completed = _status == TaskStatus.completed
        ? (widget.task.completed ?? DateTime.now().toUtc())
        : null;
    final repo = ref.read(taskRepositoryProvider);
    await repo.update(
      widget.task.copyWith(
        summary: _summaryCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        due: _due,
        status: _status,
        priority: _priority,
        percent: _percent,
        categories: _categories,
        completed: completed,
        lastModified: DateTime.now().toUtc(),
      ),
    );
    if (mounted) {
      setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          Expanded(
            child: Text(
              _editing ? '编辑任务' : '任务详情',
              style: theme.textTheme.titleLarge,
            ),
          ),
          if (!_editing)
            IconButton(
              tooltip: '编辑',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: _editing ? _buildEditBody(theme, scheme) : _buildViewBody(theme, scheme),
        ),
      ),
      actions: _editing
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: _save,
                child: const Text('保存'),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ],
    );
  }

  Widget _buildViewBody(ThemeData theme, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildInfoRow(theme, '标题', widget.task.summary),
        if (widget.task.description.trim().isNotEmpty)
          _buildInfoRow(theme, '描述', widget.task.description),
        _buildInfoRow(
          theme,
          '状态',
          _statusText(widget.task.status),
        ),
        _buildInfoRow(
          theme,
          '优先级',
          _priorityText(widget.task.priority),
        ),
        if (widget.task.due != null)
          _buildInfoRow(
            theme,
            '截止时间',
            DateFormat('yyyy-MM-dd HH:mm').format(widget.task.due!.toLocal()),
          ),
        if (widget.task.categories.isNotEmpty)
          _buildInfoRow(
            theme,
            '标签',
            widget.task.categories.join('，'),
          ),
        _buildInfoRow(
          theme,
          '完成度',
          '${widget.task.percent}%',
        ),
      ],
    );
  }

  Widget _buildEditBody(ThemeData theme, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _summaryCtrl,
          decoration: const InputDecoration(labelText: '标题'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descCtrl,
          decoration: const InputDecoration(labelText: '描述'),
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        _buildStatusSelector(scheme),
        const SizedBox(height: 12),
        _buildPrioritySelector(scheme),
        const SizedBox(height: 12),
        _buildDueDateSelector(theme, scheme),
        const SizedBox(height: 12),
        _buildPercentSlider(scheme),
        const SizedBox(height: 12),
        _buildCategoriesEditor(theme, scheme),
      ],
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSelector(ColorScheme scheme) {
    return Row(
      children: [
        Text('状态', style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(width: 16),
        SegmentedButton<TaskStatus>(
          segments: TaskStatus.values
              .where((s) => s != TaskStatus.cancelled)
              .map(
                (s) => ButtonSegment(
                  value: s,
                  label: Text(_statusText(s)),
                ),
              )
              .toList(),
          selected: {_status},
          onSelectionChanged: (set) {
            if (set.isNotEmpty) setState(() => _status = set.first);
          },
        ),
      ],
    );
  }

  Widget _buildPrioritySelector(ColorScheme scheme) {
    return Row(
      children: [
        Text('优先级', style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(width: 16),
        SegmentedButton<TaskPriority>(
          segments: TaskPriority.values.map(
            (p) => ButtonSegment(
              value: p,
              label: Text(_priorityText(p)),
            ),
          ).toList(),
          selected: {_priority},
          onSelectionChanged: (set) {
            if (set.isNotEmpty) setState(() => _priority = set.first);
          },
        ),
      ],
    );
  }

  Widget _buildDueDateSelector(ThemeData theme, ColorScheme scheme) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _due?.toLocal() ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          setState(() {
            _due = picked.toUtc();
          });
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(labelText: '截止时间'),
        child: Text(
          _due != null
              ? DateFormat('yyyy-MM-dd').format(_due!.toLocal())
              : '未设置',
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }

  Widget _buildPercentSlider(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('完成度', style: TextStyle(color: scheme.onSurfaceVariant)),
        Slider(
          value: _percent.toDouble(),
          min: 0,
          max: 100,
          divisions: 10,
          label: '$_percent%',
          onChanged: (v) => setState(() => _percent = v.round()),
        ),
      ],
    );
  }

  Widget _buildCategoriesEditor(ThemeData theme, ColorScheme scheme) {
    return TextField(
      controller: TextEditingController(text: _categories.join(', ')),
      decoration: const InputDecoration(labelText: '标签（用逗号分隔）'),
      onChanged: (v) {
        _categories = v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      },
    );
  }

  String _statusText(TaskStatus status) {
    return switch (status) {
      TaskStatus.needsAction => '待处理',
      TaskStatus.inProcess => '进行中',
      TaskStatus.completed => '已完成',
      TaskStatus.cancelled => '已取消',
    };
  }

  String _priorityText(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.none => '无',
      TaskPriority.high => '高',
      TaskPriority.medium => '中',
      TaskPriority.low => '低',
    };
  }
}
