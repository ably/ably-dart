import 'channel_state.dart';

/// Channel events include all states plus update event.
enum ChannelEvent {
  initialized,
  attaching,
  attached,
  detaching,
  detached,
  suspended,
  failed,

  /// Channel conditions changed without state change (RTL2g).
  update,
}

extension ChannelEventExtension on ChannelEvent {
  /// Converts ChannelState to ChannelEvent.
  static ChannelEvent fromState(ChannelState state) {
    switch (state) {
      case ChannelState.initialized:
        return ChannelEvent.initialized;
      case ChannelState.attaching:
        return ChannelEvent.attaching;
      case ChannelState.attached:
        return ChannelEvent.attached;
      case ChannelState.detaching:
        return ChannelEvent.detaching;
      case ChannelState.detached:
        return ChannelEvent.detached;
      case ChannelState.suspended:
        return ChannelEvent.suspended;
      case ChannelState.failed:
        return ChannelEvent.failed;
    }
  }
}
