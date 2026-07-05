/// 统一错误类型。
///
/// 用 [Failure] 表示业务层错误，避免把异常细节直接抛到 UI。
sealed class Failure {
  const Failure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// 网络相关错误（连接失败、超时等）
class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// CalDAV 协议错误（认证失败、响应解析失败等）
class CalDavFailure extends Failure {
  const CalDavFailure(super.message);
}

/// 本地数据库错误
class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

/// 参数 / 状态错误
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}
