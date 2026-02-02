/// Connection states as defined by RTN27.
enum ConnectionState {
  /// Initial state before any connection attempt.
  initialized,

  /// Library is actively attempting to connect.
  connecting,

  /// Successfully connected to Ably.
  connected,

  /// Not connected but will retry after disconnectedRetryTimeout.
  disconnected,

  /// Connection suspended after exceeding connectionStateTtl.
  suspended,

  /// User requested close() and waiting for confirmation.
  closing,

  /// Explicitly closed by user.
  closed,

  /// Encountered unrecoverable failure.
  failed,
}
