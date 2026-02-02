import '../../error/ably_exception.dart';
import '../../error/error_info.dart';

/// Classifies errors for retry and fallback logic.
///
/// Determines whether errors are fatal, token-related, or retry-worthy,
/// helping decide when to use fallback hosts or give up.
///
/// Spec: RSC15l, RTN14b, RTN15h, RTN17f
class ErrorClassifier {
  /// Checks if an error is a token error that may be renewable.
  ///
  /// Token errors have codes in range 40140-40149 or status code 401.
  ///
  /// Spec: RTN14b, RTN15h, RSA4b
  static bool isTokenError(ErrorInfo error) {
    if (error.statusCode == 401) return true;

    final code = error.code;
    if (code == null) return false;

    return code >= 40140 && code < 40150;
  }

  /// Checks if an error is fatal and should not be retried.
  ///
  /// Fatal errors include:
  /// - 5xxxx series Ably error codes (50000-59999)
  /// - 400 Bad Request errors (except token errors)
  ///
  /// Spec: RTN14g, RTN15
  static bool isFatalError(ErrorInfo error) {
    final code = error.code;

    // 5xxxx errors are generally fatal
    if (code != null && code >= 50000 && code < 60000) {
      return true;
    }

    // 400 errors (except token errors) are fatal
    if (error.statusCode == 400 && !isTokenError(error)) {
      return true;
    }

    return false;
  }

  /// Checks if an error should trigger fallback host retry.
  ///
  /// Retry-worthy errors include:
  /// - Network errors (no status code)
  /// - 5xx server errors (500-599)
  /// - Timeout errors
  /// - Host unreachable errors
  ///
  /// Spec: RSC15l, RTN17f
  static bool shouldRetryWithFallback(ErrorInfo error) {
    final statusCode = error.statusCode;

    // Network errors (no status code) - retry
    if (statusCode == null) return true;

    // RSC15l3, RTN17f: 5xx errors should use fallback
    if (statusCode >= 500 && statusCode < 600) return true;

    // Timeout errors - retry
    if (statusCode == 408) return true;

    // Don't retry 4xx errors (client errors)
    return false;
  }

  /// Checks if an AblyException should trigger fallback retry.
  ///
  /// Convenience method that extracts ErrorInfo from AblyException.
  static bool shouldRetryException(AblyException exception) {
    final errorInfo = exception.errorInfo;
    if (errorInfo == null) return true; // Unknown error - retry

    return shouldRetryWithFallback(errorInfo);
  }

  /// Checks if a DISCONNECTED message should trigger fallback.
  ///
  /// DISCONNECTED with 5xx status codes (500-504) should use fallback.
  ///
  /// Spec: RTN17f1
  static bool shouldDisconnectedUseFallback(ErrorInfo error) {
    final statusCode = error.statusCode;
    if (statusCode == null) return false;

    // RTN17f1: DISCONNECTED with 500-504 uses fallback
    return statusCode >= 500 && statusCode <= 504;
  }
}
