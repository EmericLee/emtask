import '../../../core/errors/failures.dart';

/// CalDAV 数据源相关异常。
class CalDavException implements Exception {
  CalDavException(this.message, {this.statusCode, this.responseBody});

  final String message;
  final int? statusCode;
  final String? responseBody;

  @override
  String toString() =>
      'CalDavException($statusCode): $message${responseBody != null ? '\nbody: $responseBody' : ''}';
}

/// 转换为 [Failure]
Failure toFailure(Object error) {
  if (error is CalDavException) {
    if (error.statusCode == 401 || error.statusCode == 403) {
      return const CalDavFailure('认证失败：请检查用户名与应用密码');
    }
    if (error.statusCode == 404) {
      return CalDavFailure('资源不存在：${error.message}');
    }
    return CalDavFailure(error.message);
  }
  return NetworkFailure(error.toString());
}
