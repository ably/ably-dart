import 'package:meta/meta.dart';

import '../error/error_info.dart';
import 'channel_event.dart';
import 'channel_state.dart';

/// Represents a channel state change event.
@immutable
class ChannelStateChange {
  /// Creates a channel state change.
  const ChannelStateChange({
    required this.event,
    required this.current,
    required this.previous,
    this.reason,
    this.resumed = false,
    this.hasBacklog,
  });

  /// The event that triggered this state change.
  final ChannelEvent event;

  /// The new channel state.
  final ChannelState current;

  /// The previous channel state.
  final ChannelState previous;

  /// Error information if the state change was due to an error.
  final ErrorInfo? reason;

  /// Whether message continuity was preserved (RTL2f).
  final bool resumed;

  /// Whether there is a backlog of messages (RTL2i).
  final bool? hasBacklog;

  @override
  String toString() => 'ChannelStateChange('
      'event: $event, '
      'current: $current, '
      'previous: $previous, '
      'reason: $reason, '
      'resumed: $resumed, '
      'hasBacklog: $hasBacklog'
      ')';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelStateChange &&
          runtimeType == other.runtimeType &&
          event == other.event &&
          current == other.current &&
          previous == other.previous &&
          reason == other.reason &&
          resumed == other.resumed &&
          hasBacklog == other.hasBacklog;

  @override
  int get hashCode =>
      event.hashCode ^
      current.hashCode ^
      previous.hashCode ^
      reason.hashCode ^
      resumed.hashCode ^
      hasBacklog.hashCode;
}
