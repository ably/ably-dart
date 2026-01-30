import 'error_info.dart';

/// Exception thrown by Ably operations.
class AblyException implements Exception {
  /// Creates an AblyException.
  const AblyException({
    String? message,
    this.errorInfo,
  }) : _message = message;

  /// Creates an AblyException from an ErrorInfo.
  factory AblyException.fromErrorInfo(ErrorInfo errorInfo) {
    return AblyException(
      message: errorInfo.message,
      errorInfo: errorInfo,
    );
  }

  final String? _message;

  /// Detailed error information.
  final ErrorInfo? errorInfo;

  /// Error message - returns errorInfo.message if not set directly.
  String? get message => _message ?? errorInfo?.message;

  /// The error code, if available.
  int? get code => errorInfo?.code;

  /// The HTTP status code, if available.
  int? get statusCode => errorInfo?.statusCode;

  @override
  String toString() {
    if (errorInfo != null) {
      return 'AblyException: $errorInfo';
    }
    return 'AblyException: $message';
  }
}
