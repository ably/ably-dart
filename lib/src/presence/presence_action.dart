/// The type of presence action.
enum PresenceAction {
  /// Not present.
  absent,

  /// Present when initial channel subscription completed.
  present,

  /// Newly entered the channel.
  enter,

  /// Left the channel.
  leave,

  /// Updated presence data.
  update,
}

/// Extension methods for PresenceAction.
extension PresenceActionExtension on PresenceAction {
  /// Converts to the string representation used by Ably.
  String toAblyString() {
    switch (this) {
      case PresenceAction.absent:
        return 'absent';
      case PresenceAction.present:
        return 'present';
      case PresenceAction.enter:
        return 'enter';
      case PresenceAction.leave:
        return 'leave';
      case PresenceAction.update:
        return 'update';
    }
  }

  /// Creates a PresenceAction from an Ably string.
  static PresenceAction fromAblyString(String value) {
    switch (value.toLowerCase()) {
      case 'absent':
        return PresenceAction.absent;
      case 'present':
        return PresenceAction.present;
      case 'enter':
        return PresenceAction.enter;
      case 'leave':
        return PresenceAction.leave;
      case 'update':
        return PresenceAction.update;
      default:
        throw ArgumentError('Unknown presence action: $value');
    }
  }
}
