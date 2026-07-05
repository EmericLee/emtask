import 'package:freezed_annotation/freezed_annotation.dart';

import 'task_status.dart';

part 'task.freezed.dart';
part 'task.g.dart';

/// 任务实体，对应 iCalendar VTODO。
///
/// 字段映射：
/// - [uid]         → UID
/// - [summary]     → SUMMARY
/// - [description] → DESCRIPTION
/// - [due]         → DUE
/// - [start]       → DTSTART
/// - [completed]   → COMPLETED
/// - [status]      → STATUS
/// - [priority]    → PRIORITY
/// - [percent]     → PERCENT-COMPLETE
/// - [categories]  → CATEGORIES
/// - [parentUid]   → RELATED-TO（父任务）
/// - [lastModified]→ LAST-MODIFIED
/// - [created]     → CREATED
/// - [sortOrder]   → X-APPLE-SORT-ORDER（手动排序，Nextcloud Tasks 兼容）
@freezed
class Task with _$Task {
  const factory Task({
    /// 本地数据库主键（本地生成，与服务端无关）
    required int localId,

    /// 远端日历 URL（标识所属日历）
    required String calendarUrl,

    /// iCalendar UID（全局唯一，CalDAV 同步主键）
    required String uid,

    /// 任务标题
    required String summary,

    /// 任务详情
    @Default('') String description,

    /// 开始时间
    DateTime? start,

    /// 截止时间
    DateTime? due,

    /// 完成时间
    DateTime? completed,

    /// 状态
    @Default(TaskStatus.needsAction) TaskStatus status,

    /// 优先级
    @Default(TaskPriority.none) TaskPriority priority,

    /// 完成百分比 0-100
    @Default(0) int percent,

    /// 分类标签
    @Default(<String>[]) List<String> categories,

    /// 父任务 UID（用于子任务）
    String? parentUid,

    /// 远端 .ics 资源 HREF（相对路径）
    String? href,

    /// 远端 ETag（同步用，乐观并发控制）
    String? etag,

    /// 创建时间
    DateTime? created,

    /// 最后修改时间
    DateTime? lastModified,

    /// 本地最后修改时间（用于离线变更追踪）
    DateTime? localModifiedAt,

    /// 手动排序值（对应 X-APPLE-SORT-ORDER，数字越小越靠前）
    int? sortOrder,

    /// 是否待同步上传
    @Default(false) bool dirty,

    /// 是否已被本地删除（待同步删除）
    @Default(false) bool deleted,
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);

  /// 创建新任务时的工厂方法（生成 UID 与默认时间）。
  factory Task.create({
    required String calendarUrl,
    required String summary,
    String description = '',
    DateTime? start,
    DateTime? due,
    TaskStatus status = TaskStatus.needsAction,
    TaskPriority priority = TaskPriority.none,
    List<String> categories = const [],
    String? parentUid,
  }) {
    final now = DateTime.now().toUtc();
    return Task(
      localId: 0,
      calendarUrl: calendarUrl,
      uid: _generateUid(),
      summary: summary,
      description: description,
      start: start,
      due: due,
      status: status,
      priority: priority,
      categories: categories,
      parentUid: parentUid,
      created: now,
      lastModified: now,
      localModifiedAt: now,
      dirty: true,
    );
  }

  static String _generateUid() {
    // 简单生成：时间戳 + 随机后缀。生产环境可换用 uuid 包。
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch;
    final suffix = DateTime.now().microsecondsSinceEpoch % 0x1000000;
    return '$ts-$suffix@emtask.local';
  }
}

/// Task 的扩展工具方法。
extension TaskX on Task {
  /// 是否已完成
  bool get isCompleted =>
      status == TaskStatus.completed || percent >= 100;

  /// 是否已过期
  bool get isOverdue {
    final d = due;
    if (d == null || isCompleted) return false;
    return d.isBefore(DateTime.now().toUtc());
  }

  /// 是否为子任务
  bool get isSubtask => parentUid != null && parentUid!.isNotEmpty;
}
