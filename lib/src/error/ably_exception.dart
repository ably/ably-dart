import 'error_info.dart';

/// Wrapper indicating a fatal error that should not be retried.
///
/// Used internally to signal that an error from an ERROR protocol message
/// should transition to FAILED state without trying fallback hosts.
class FatalErrorException implements Exception {
  /// Creates a FatalErrorException.
  const FatalErrorException(this.errorInfo);

  /// The underlying error information.
  final ErrorInfo errorInfo;

  @override
  String toString() => 'FatalErrorException: $errorInfo';
}

/// Marker exception indicating the error was already handled.
///
/// Used internally when token errors are processed directly via _handleTokenError
/// and the catch block in _startConnection should not process the error further.
class HandledErrorException implements Exception {
  /// Creates a HandledErrorException.
  const HandledErrorException();

  @override
  String toString() => 'HandledErrorException: Error was already handled';
}

/// Exception thrown by Ably operations.
class AblyException implements Exception {
  /// Creates an AblyException.
  const AblyException({
    String? message,
    this.errorInfo,
    this.isRetryable = false,
  }) : _message = message;

  /// Creates an AblyException from an ErrorInfo.
  factory AblyException.fromErrorInfo(
    ErrorInfo errorInfo, {
    bool isRetryable = false,
  }) {
    return AblyException(
      message: errorInfo.message,
      errorInfo: errorInfo,
      isRetryable: isRetryable,
    );
  }

  final String? _message;

  /// Detailed error information.
  final ErrorInfo? errorInfo;

  /// Whether this error should trigger fallback retry regardless of status code.
  ///
  /// RSC15l4: CloudFront errors (Server: CloudFront header with status >= 400)
  /// are retryable even though they have 4xx status codes.
  final bool isRetryable;

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
