/// 任务状态，对应 iCalendar VTODO 的 STATUS 属性（RFC 5545）。
enum TaskStatus {
  /// 需要处理（未开始）
  needsAction('NEEDS-ACTION'),

  /// 进行中
  inProcess('IN-PROCESS'),

  /// 已完成
  completed('COMPLETED'),

  /// 已取消
  cancelled('CANCELLED');

  const TaskStatus(this.icalValue);

  final String icalValue;

  static TaskStatus fromIcal(String? value) {
    return TaskStatus.values.firstWhere(
      (e) => e.icalValue == value,
      orElse: () => TaskStatus.needsAction,
    );
  }
}

/// 任务优先级，对应 iCalendar PRIORITY（1 最高，5 普通，9 最低，0 无）。
enum TaskPriority {
  none(0),
  high(1),
  medium(5),
  low(9);

  const TaskPriority(this.icalValue);

  final int icalValue;

  static TaskPriority fromIcal(int? value) {
    if (value == null || value == 0) return TaskPriority.none;
    if (value <= 3) return TaskPriority.high;
    if (value <= 7) return TaskPriority.medium;
    return TaskPriority.low;
  }
}
