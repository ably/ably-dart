import 'package:meta/meta.dart';

/// Contains error information returned from Ably.
///
/// Spec: TI1, TI2
@immutable
class ErrorInfo implements Exception {
  /// Creates an ErrorInfo instance.
  const ErrorInfo({
    this.code,
    this.statusCode,
    this.message,
    this.href,
    this.requestId,
    this.cause,
  });

  /// Creates an ErrorInfo from a JSON map.
  factory ErrorInfo.fromMap(Map<String, dynamic> map) {
    return ErrorInfo(
      code: map['code'] as int?,
      statusCode: map['statusCode'] as int?,
      message: map['message'] as String?,
      href: map['href'] as String?,
      requestId: map['requestId'] as String?,
      cause: map['cause'] != null
          ? ErrorInfo.fromMap(map['cause'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Creates an ErrorInfo from a JSON map.
  ///
  /// Alias for [fromMap].
  factory ErrorInfo.fromJson(Map<String, dynamic> json) = ErrorInfo.fromMap;

  /// Ably error code.
  ///
  /// See: https://ably.com/docs/api/realtime-sdk/types#error-info
  final int? code;

  /// HTTP status code associated with the error.
  final int? statusCode;

  /// Error message.
  final String? message;

  /// URL to documentation about the error.
  final String? href;

  /// Request ID for tracing.
  final String? requestId;

  /// The underlying cause of this error, if any.
  /// Can be an Exception or another ErrorInfo.
  final Object? cause;

  /// Returns the help URL for this error code.
  String? get helpUrl {
    if (href != null) return href;
    if (code != null) return 'https://help.ably.io/error/$code';
    return null;
  }

  @override
  String toString() {
    final parts = <String>[];
    if (code != null) parts.add('code=$code');
    if (statusCode != null) parts.add('statusCode=$statusCode');
    if (message != null) parts.add('message=$message');
    if (requestId != null) parts.add('requestId=$requestId');
    if (href != null) parts.add('href=$href');
    return 'ErrorInfo(${parts.join(', ')})';
  }

  /// Converts this ErrorInfo to a JSON map.
  Map<String, dynamic> toMap() {
    return {
      if (code != null) 'code': code,
      if (statusCode != null) 'statusCode': statusCode,
      if (message != null) 'message': message,
      if (href != null) 'href': href,
      if (requestId != null) 'requestId': requestId,
      if (cause is ErrorInfo) 'cause': (cause! as ErrorInfo).toMap(),
    };
  }

  /// Converts this ErrorInfo to a JSON map.
  ///
  /// Alias for [toMap].
  Map<String, dynamic> toJson() => toMap();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ErrorInfo &&
        other.code == code &&
        other.statusCode == statusCode &&
        other.message == message &&
        other.href == href &&
        other.requestId == requestId &&
        other.cause == cause;
  }

  @override
  int get hashCode {
    return Object.hash(code, statusCode, message, href, requestId, cause);
  }
}
