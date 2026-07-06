import 'dart:typed_data';

import 'package:flutter/material.dart' show Color, Colors;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/task.dart';
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

  widgets.add(
    pw.Padding(
      padding: pw.EdgeInsets.only(left: depth * 16.0, top: 2, bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // 状态复选框：用 Container 绘制，避免依赖特殊字符字体。
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
                    child: pw.Text(
                      '✓',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          ),
          pw.SizedBox(width: 6),
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
                      '↳ $parentPath',
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
                    if (task.due != null) ...[
                      pw.SizedBox(width: 8),
                      pw.Text(
                        dueFmt.format(task.due!.toLocal()),
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
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

/// 将 Flutter [Color] 转换为 [PdfColor]。
PdfColor _toPdfColor(Color color) {
  return PdfColor(
    color.red / 255,
    color.green / 255,
    color.blue / 255,
    color.alpha / 255,
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
    return parts.reversed.join(' › ');
  }
}
