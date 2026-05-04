/// Channel states as defined by RTL2.
enum ChannelState {
  /// Initial state when channel is created.
  initialized,

  /// Attach request in progress.
  attaching,

  /// Successfully attached and receiving messages.
  attached,

  /// Detach request in progress.
  detaching,

  /// Successfully detached.
  detached,

  /// Channel suspended due to connection issues.
  suspended,

  /// Channel in failed state.
  failed,
}
