import 'package:meta/meta.dart';

import '../error/error_info.dart';
import '../message/presence_message.dart';

/// Response from a batch presence request.
///
/// Contains per-channel results with computed [successCount] and
/// [failureCount] fields (BAR2).
///
/// The server returns different formats depending on the outcome:
/// - All success (HTTP 200): plain array of per-channel results
/// - Mixed/failure (HTTP 400): `{error: ..., batchResponse: [...]}`
///
/// This class normalises both formats into a single interface.
///
/// Spec: RSC24, BAR2
@immutable
class BatchPresenceResponse {
  /// Creates a BatchPresenceResponse.
  const BatchPresenceResponse({
    required this.successCount,
    required this.failureCount,
    required this.results,
  });

  /// Creates a BatchPresenceResponse from a list of per-channel results.
  ///
  /// This is the format returned by the server on HTTP 200 (all success).
  factory BatchPresenceResponse.fromList(List<dynamic> list) {
    final results = list
        .cast<Map<String, dynamic>>()
        .map(BatchPresenceResult.fromMap)
        .toList();

    final successCount = results.where((r) => r.isSuccess).length;
    final failureCount = results.where((r) => r.isFailure).length;

    return BatchPresenceResponse(
      successCount: successCount,
      failureCount: failureCount,
      results: results,
    );
  }

  /// The number of successful per-channel results.
  ///
  /// Spec: BAR2a
  final int successCount;

  /// The number of unsuccessful per-channel results.
  ///
  /// Spec: BAR2b
  final int failureCount;

  /// The per-channel results.
  ///
  /// Spec: BAR2c
  final List<BatchPresenceResult> results;
}

/// Base class for per-channel batch presence results.
///
/// A result can be either a [BatchPresenceSuccessResult] or a
/// [BatchPresenceFailureResult].
@immutable
sealed class BatchPresenceResult {
  const BatchPresenceResult({required this.channel});

  /// The channel this result is for.
  final String channel;

  /// Whether this result is a success.
  bool get isSuccess;

  /// Whether this result is a failure.
  bool get isFailure => !isSuccess;

  /// Creates a BatchPresenceResult from a JSON map.
  factory BatchPresenceResult.fromMap(Map<String, dynamic> map) {
    final channel = map['channel'] as String;

    if (map.containsKey('error')) {
      return BatchPresenceFailureResult(
        channel: channel,
        error: ErrorInfo.fromMap(map['error'] as Map<String, dynamic>),
      );
    } else {
      final presenceList = (map['presence'] as List?)
              ?.cast<Map<String, dynamic>>()
              .map(PresenceMessage.fromMap)
              .toList() ??
          [];
      return BatchPresenceSuccessResult(
        channel: channel,
        presence: presenceList,
      );
    }
  }
}

/// Result of a successful batch presence request for a single channel.
///
/// Spec: BGR2
@immutable
class BatchPresenceSuccessResult extends BatchPresenceResult {
  /// Creates a BatchPresenceSuccessResult.
  const BatchPresenceSuccessResult({
    required super.channel,
    required this.presence,
  });

  /// The presence members on the channel.
  ///
  /// Spec: BGR2b
  final List<PresenceMessage> presence;

  @override
  bool get isSuccess => true;
}

/// Result of an unsuccessful batch presence request for a single channel.
///
/// Spec: BGF2
@immutable
class BatchPresenceFailureResult extends BatchPresenceResult {
  /// Creates a BatchPresenceFailureResult.
  const BatchPresenceFailureResult({
    required super.channel,
    required this.error,
  });

  /// The error indicating why the presence request failed.
  ///
  /// Spec: BGF2b
  final ErrorInfo error;

  @override
  bool get isSuccess => false;
}
