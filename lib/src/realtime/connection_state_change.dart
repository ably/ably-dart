import 'package:meta/meta.dart';

import '../error/error_info.dart';
import 'connection_event.dart';
import 'connection_state.dart';

/// Represents a connection state change event.
@immutable
class ConnectionStateChange {
  /// Creates a connection state change.
  const ConnectionStateChange({
    required this.event,
    required this.current,
    required this.previous,
    this.reason,
    this.retryIn,
  });

  /// The event that triggered this state change.
  final ConnectionEvent event;

  /// The new connection state.
  final ConnectionState current;

  /// The previous connection state.
  final ConnectionState previous;

  /// Error information if the state change was due to an error.
  final ErrorInfo? reason;

  /// Time in milliseconds until automatic retry (for disconnected/suspended).
  final int? retryIn;

  @override
  String toString() => 'ConnectionStateChange('
      'event: $event, '
      'current: $current, '
      'previous: $previous, '
      'reason: $reason, '
      'retryIn: $retryIn'
      ')';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectionStateChange &&
          runtimeType == other.runtimeType &&
          event == other.event &&
          current == other.current &&
          previous == other.previous &&
          reason == other.reason &&
          retryIn == other.retryIn;

  @override
  int get hashCode =>
      event.hashCode ^
      current.hashCode ^
      previous.hashCode ^
      reason.hashCode ^
      retryIn.hashCode;
}
