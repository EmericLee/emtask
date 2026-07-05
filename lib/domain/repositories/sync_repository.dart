/// 同步仓储抽象，封装与服务端的同步流程。
abstract class SyncRepository {
  /// 执行一次完整同步：
  /// 1. 上传本地 dirty / deleted 任务
  /// 2. 拉取远端变更（基于 ctag / sync-token）
  /// 3. 冲突处理（远端优先 / 本地优先 / 手动合并）
  Future<SyncResult> sync();

  /// 仅上传本地变更
  Future<SyncResult> push();

  /// 仅拉取远端变更
  Future<SyncResult> pull();
}

/// 单次同步结果。
class SyncResult {
  const SyncResult({
    this.uploaded = 0,
    this.downloaded = 0,
    this.updated = 0,
    this.deleted = 0,
    this.conflicts = 0,
    this.error,
    this.finishedAt,
  });

  /// 上传到远端的任务数
  final int uploaded;

  /// 从远端下载的任务数
  final int downloaded;

  /// 本地被远端数据更新的任务数
  final int updated;

  /// 本地被远端删除的任务数
  final int deleted;

  /// 冲突数量
  final int conflicts;

  /// 同步过程错误（不致命时部分成功）
  final Object? error;

  /// 完成时间
  final DateTime? finishedAt;

  bool get isSuccess => error == null;

  @override
  String toString() =>
      'SyncResult(uploaded=$uploaded, downloaded=$downloaded, '
      'updated=$updated, deleted=$deleted, conflicts=$conflicts, '
      'success=$isSuccess)';
}
