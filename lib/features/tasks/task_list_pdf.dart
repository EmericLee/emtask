import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart' show Color, Colors;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/task.dart';
import '../../domain/entities/task_status.dart';
import 'task_providers.dart';

/// 构建任务清单 PDF。
///
/// 按日历分组、树状缩进显示任务。前缀模式下，孤儿子任务标题上方
/// 会显示父路径前缀（如 "↳ 父任务 › 子任务"）。
///
/// 字体从本地 asset 加载（assets/fonts/NotoSansSC-*.ttf），
/// 不依赖网络，可离线工作且跨平台。
Future<Uint8List> buildTaskListPdf({
  required Map<String, List<Task>> groups,
  required Map<String, Color> calendarColors,
  required OrphanDisplayMode orphanMode,
  required List<Task> allTasks,
}) async {
  // 从本地 asset 加载中文字体（离线可用，跨平台一致）。
  // 使用可变字体，pdf 包取默认实例（wght=400）；Bold 亦用同一字体（与此前效果一致）。
  final fontData =
      await rootBundle.load('assets/fonts/NotoSansSC-Variable.ttf');
  final font = pw.Font.ttf(fontData);
  final boldFont = font;

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: boldFont),
  );

  final widgets = <pw.Widget>[];
  final now = DateTime.now();
  final fmt = DateFormat('yyyy-MM-dd HH:mm');
  final dueFmt = DateFormat('MM/dd');
  final totalCount = groups.values.fold<int>(0, (n, l) => n + l.length);

  // 标题区
  widgets.add(
    pw.Text(
      '当前任务清单',
      style: pw.TextStyle(font: boldFont, fontSize: 22),
    ),
  );
  widgets.add(
    pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
      child: pw.Text(
        '生成时间：${fmt.format(now)}    任务总数：$totalCount',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
      ),
    ),
  );
  widgets.add(pw.Divider());

  // 按日历分组渲染
  for (final entry in groups.entries) {
    final category = entry.key;
    final tasks = entry.value;
    final firstUrl = tasks.firstOrNull?.calendarUrl;
    final calColor = firstUrl != null && calendarColors.containsKey(firstUrl)
        ? calendarColors[firstUrl]!
        : Colors.grey;

    // 分组标题
    widgets.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Row(
          children: [
            pw.Container(
              width: 9,
              height: 9,
              margin: const pw.EdgeInsets.only(right: 8),
              decoration: pw.BoxDecoration(
                color: _toPdfColor(calColor),
                shape: pw.BoxShape.circle,
              ),
            ),
            pw.Text(
              category,
              style: pw.TextStyle(font: boldFont, fontSize: 14),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              '(${tasks.length})',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );

    // 构建任务树
    final tree = _PdfTaskTree(tasks, allTasks: allTasks);
    for (final root in tree.roots) {
      _buildNode(
        tree,
        root,
        depth: 0,
        widgets: widgets,
        font: font,
        boldFont: boldFont,
        orphanMode: orphanMode,
        dueFmt: dueFmt,
      );
    }
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (context) => pw.Text(
        '当前任务清单  ·  ${fmt.format(now)}',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
      ),
      build: (context) => widgets,
    ),
  );

  return doc.save();
}

void _buildNode(
  _PdfTaskTree tree,
  Task task, {
  required int depth,
  required List<pw.Widget> widgets,
  required pw.Font font,
  required pw.Font boldFont,
  required OrphanDisplayMode orphanMode,
  required DateFormat dueFmt,
}) {
  final children = tree.childrenOf(task.uid);
  final parentPath = tree.parentPathOf(task.uid);
  final hasNote = task.description.trim().isNotEmpty;

  widgets.add(
    pw.Padding(
      padding: pw.EdgeInsets.only(left: depth * 16.0, top: 2, bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // 展开指示器占位
          if (children.isNotEmpty)
            pw.SizedBox(width: 12)
          else
            pw.SizedBox(width: 12),
          // 状态复选框
          pw.Container(
            width: 10,
            height: 10,
            margin: const pw.EdgeInsets.only(top: 2),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: task.isCompleted ? PdfColors.green700 : PdfColors.grey500,
                width: 0.8,
              ),
              color: task.isCompleted ? PdfColors.green700 : null,
              borderRadius: pw.BorderRadius.circular(2),
            ),
            child: task.isCompleted
                ? pw.Center(
                    child: _drawCheckmark(PdfColors.white, 7),
                  )
                : null,
          ),
          pw.SizedBox(width: 4),
          // 优先级五角星：高=红色实心、中=蓝色空心、低=浅灰空心
          if (task.priority != TaskPriority.none) ...[
            _buildPriorityStar(task.priority, 10),
            pw.SizedBox(width: 4),
          ],
          // 标题区
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 前缀模式：孤儿任务的父路径前缀
                if (parentPath != null &&
                    orphanMode == OrphanDisplayMode.prefix)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 1),
                    child: pw.Text(
                      '> $parentPath',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        task.summary,
                        style: pw.TextStyle(
                          font: task.isCompleted ? font : boldFont,
                          fontSize: 11,
                          color: task.isCompleted
                              ? PdfColors.grey600
                              : PdfColors.black,
                          decoration: task.isCompleted
                              ? pw.TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    // 状态图标（与任务条一致，矢量绘制避免字体缺失）
                    if (task.status != TaskStatus.needsAction)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 4),
                        child: _drawStatusIcon(
                          task.status,
                          _statusColor(task.status),
                          10,
                        ),
                      ),
                    // 完成度
                    if (task.percent > 0 && task.percent < 100)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 4),
                        child: pw.Text(
                          '${task.percent}%',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ),
                    // 描述图标（矢量绘制，避免 emoji 字体缺失）
                    if (hasNote)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 4, top: 1),
                        child: _drawDocIcon(PdfColors.grey600, 9),
                      ),
                    // 标签
                    ...task.categories.map(
                      (tag) => pw.Container(
                        margin: const pw.EdgeInsets.only(left: 4),
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue50,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Text(
                          tag,
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.blue800,
                          ),
                        ),
                      ),
                    ),
                    // 截止日期
                    if (task.due != null) ...[
                      pw.SizedBox(width: 6),
                      pw.Text(
                        dueFmt.format(task.due!.toLocal()),
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: task.isOverdue
                              ? PdfColors.red700
                              : PdfColors.grey600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  for (final child in children) {
    _buildNode(
      tree,
      child,
      depth: depth + 1,
      widgets: widgets,
      font: font,
      boldFont: boldFont,
      orphanMode: orphanMode,
      dueFmt: dueFmt,
    );
  }
}

/// 状态颜色。
PdfColor _statusColor(TaskStatus s) => switch (s) {
      TaskStatus.inProcess => PdfColors.blue800,
      TaskStatus.completed => PdfColors.green700,
      TaskStatus.cancelled => PdfColors.grey500,
      _ => PdfColors.black,
    };

/// 将 Flutter [Color] 转换为 [PdfColor]。
PdfColor _toPdfColor(Color color) {
  return PdfColor(
    color.red / 255,
    color.green / 255,
    color.blue / 255,
    color.alpha / 255,
  );
}

/// 绘制优先级五角星：高=红色实心、中=蓝色空心、低=浅灰空心。
/// 使用 CustomPaint 直接绘制矢量路径，避免字体符号显示异常。
pw.Widget _buildPriorityStar(TaskPriority priority, double size) {
  final isFilled = priority == TaskPriority.high;
  final color = switch (priority) {
    TaskPriority.high => PdfColors.red700,
    TaskPriority.medium => PdfColors.blue700,
    TaskPriority.low => PdfColors.blue700,
    TaskPriority.none => PdfColors.grey400,
  };

  return pw.CustomPaint(
    size: PdfPoint(size, size),
    painter: (canvas, sz) {
      final cx = sz.x / 2;
      final cy = sz.y / 2;
      final outer = sz.x / 2;
      final inner = outer * 0.4;

      canvas.saveContext();
      canvas.setFillColor(color);
      canvas.setStrokeColor(color);
      canvas.setLineWidth(0.8);

      // 构建 5 角星路径（10 个交替顶点，从顶部开始）
      for (var i = 0; i < 10; i++) {
        final angle = math.pi / 2 + i * math.pi / 5;
        final r = i.isEven ? outer : inner;
        final x = cx + r * math.cos(angle);
        final y = cy + r * math.sin(angle);
        if (i == 0) {
          canvas.moveTo(x, y);
        } else {
          canvas.lineTo(x, y);
        }
      }
      canvas.closePath();

      // 实心星：填充；空心星：仅描边
      if (isFilled) {
        canvas.fillPath();
      } else {
        canvas.strokePath();
      }
      canvas.restoreContext();
    },
  );
}

/// 矢量绘制复选标记 ✓。
pw.Widget _drawCheckmark(PdfColor color, double size) {
  return pw.CustomPaint(
    size: PdfPoint(size, size),
    painter: (canvas, sz) {
      canvas.saveContext();
      canvas.setStrokeColor(color);
      canvas.setLineWidth(size * 0.18);
      canvas.setLineCap(PdfLineCap.round);
      canvas.setLineJoin(PdfLineJoin.round);
      // ✓ 路径：左下 → 中下 → 右上
      canvas.moveTo(sz.x * 0.15, sz.y * 0.50);
      canvas.lineTo(sz.x * 0.40, sz.y * 0.25);
      canvas.lineTo(sz.x * 0.85, sz.y * 0.75);
      canvas.strokePath();
      canvas.restoreContext();
    },
  );
}

/// 矢量绘制状态图标。
/// - inProcess：时钟（简化版 pending_actions）
/// - completed：✓ 复选标记
/// - cancelled：✕ 叉号
pw.Widget _drawStatusIcon(TaskStatus status, PdfColor color, double size) {
  return pw.CustomPaint(
    size: PdfPoint(size, size),
    painter: (canvas, sz) {
      canvas.saveContext();
      canvas.setStrokeColor(color);
      canvas.setLineWidth(size * 0.14);
      canvas.setLineCap(PdfLineCap.round);
      canvas.setLineJoin(PdfLineJoin.round);

      switch (status) {
        case TaskStatus.inProcess:
          // 时钟图标（对应应用界面的 Icons.pending_actions）
          final cx = sz.x / 2;
          final cy = sz.y / 2;
          final r = sz.x * 0.38;
          // 时钟外圈
          for (var i = 0; i <= 32; i++) {
            final a = i * 2 * math.pi / 32;
            final px = cx + r * math.cos(a);
            final py = cy + r * math.sin(a);
            if (i == 0) {
              canvas.moveTo(px, py);
            } else {
              canvas.lineTo(px, py);
            }
          }
          canvas.strokePath();
          // 时针（指向 12 点方向，短）
          canvas.moveTo(cx, cy);
          canvas.lineTo(cx, cy + r * 0.5);
          canvas.strokePath();
          // 分针（指向 3 点方向，长）
          canvas.moveTo(cx, cy);
          canvas.lineTo(cx + r * 0.7, cy);
          canvas.strokePath();

        case TaskStatus.completed:
          // ✓ 复选标记
          canvas.moveTo(sz.x * 0.15, sz.y * 0.50);
          canvas.lineTo(sz.x * 0.40, sz.y * 0.25);
          canvas.lineTo(sz.x * 0.85, sz.y * 0.75);
          canvas.strokePath();

        case TaskStatus.cancelled:
          // ✕ 叉号
          canvas.moveTo(sz.x * 0.20, sz.y * 0.20);
          canvas.lineTo(sz.x * 0.80, sz.y * 0.80);
          canvas.moveTo(sz.x * 0.80, sz.y * 0.20);
          canvas.lineTo(sz.x * 0.20, sz.y * 0.80);
          canvas.strokePath();

        default:
          break;
      }
      canvas.restoreContext();
    },
  );
}

/// 矢量绘制文档图标（用于描述标记）。
pw.Widget _drawDocIcon(PdfColor color, double size) {
  return pw.CustomPaint(
    size: PdfPoint(size * 0.8, size),
    painter: (canvas, sz) {
      canvas.saveContext();
      canvas.setStrokeColor(color);
      canvas.setFillColor(color);
      canvas.setLineWidth(0.5);

      // 文档外框（右上角折角）
      const fold = 0.3; // 折角比例
      final w = sz.x;
      final h = sz.y;
      final foldSize = w * fold;

      canvas.moveTo(0, 0);
      canvas.lineTo(w - foldSize, 0);
      canvas.lineTo(w, foldSize);
      canvas.lineTo(w, h);
      canvas.lineTo(0, h);
      canvas.closePath();
      canvas.strokePath();

      // 折角线
      canvas.moveTo(w - foldSize, 0);
      canvas.lineTo(w - foldSize, foldSize);
      canvas.lineTo(w, foldSize);
      canvas.strokePath();

      // 内容线
      canvas.setLineWidth(0.4);
      final lineY1 = h * 0.45;
      final lineY2 = h * 0.65;
      canvas.moveTo(w * 0.2, lineY1);
      canvas.lineTo(w * 0.7, lineY1);
      canvas.moveTo(w * 0.2, lineY2);
      canvas.lineTo(w * 0.7, lineY2);
      canvas.strokePath();

      canvas.restoreContext();
    },
  );
}

/// PDF 专用任务树，复用与 [_WorkTaskTree] 相同的孤儿提升逻辑。
class _PdfTaskTree {
  _PdfTaskTree(List<Task> tasks, {List<Task> allTasks = const []}) {
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
        if (p != null &&
            p.isNotEmpty &&
            !uids.contains(p) &&
            allUidToTask.containsKey(p)) {
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
  List<Task> childrenOf(String parentUid) =>
      _children[parentUid] ?? const [];
  String? parentPathOf(String uid) => _parentPaths[uid];

  static String _buildPath(String uid, Map<String, Task> allTasks) {
    final parts = <String>[];
    String? current = uid;
    while (current != null && allTasks.containsKey(current)) {
      final t = allTasks[current]!;
      parts.add(t.summary);
      current = t.parentUid;
    }
    return parts.reversed.join(' > ');
  }
}
