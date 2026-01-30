import 'package:meta/meta.dart';

import '../error/error_info.dart';

/// Base class for batch publish results.
///
/// A batch result can be either a success or a failure.
@immutable
sealed class BatchResult {
  const BatchResult({required this.channel});

  /// The channel this result is for.
  final String channel;

  /// Whether this result is a success.
  bool get isSuccess;

  /// Whether this result is a failure.
  bool get isFailure => !isSuccess;

  /// Creates a BatchResult from a JSON map.
  factory BatchResult.fromMap(Map<String, dynamic> map) {
    final channel = map['channel'] as String;

    if (map.containsKey('error')) {
      return BatchPublishFailureResult(
        channel: channel,
        error: ErrorInfo.fromMap(map['error'] as Map<String, dynamic>),
      );
    } else {
      return BatchPublishSuccessResult(
        channel: channel,
        messageId: map['messageId'] as String?,
        serials: (map['serials'] as List?)?.cast<String?>(),
      );
    }
  }
}

/// Result of a successful batch publish for a single channel.
///
/// Spec: BPR2
@immutable
class BatchPublishSuccessResult extends BatchResult {
  /// Creates a BatchPublishSuccessResult.
  const BatchPublishSuccessResult({
    required super.channel,
    this.messageId,
    this.serials,
  });

  /// The message ID prefix.
  ///
  /// Spec: BPR2b
  final String? messageId;

  /// Array of message serials.
  ///
  /// May contain null for conflated messages.
  ///
  /// Spec: BPR2c, BPR2c1
  final List<String?>? serials;

  @override
  bool get isSuccess => true;
}

/// Result of a failed batch publish for a single channel.
///
/// Spec: BPF2
@immutable
class BatchPublishFailureResult extends BatchResult {
  /// Creates a BatchPublishFailureResult.
  const BatchPublishFailureResult({
    required super.channel,
    required this.error,
  });

  /// The error that caused the failure.
  ///
  /// Spec: BPF2b
  final ErrorInfo error;

  @override
  bool get isSuccess => false;
}
