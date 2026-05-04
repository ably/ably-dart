import 'connection_state.dart';

/// Connection events include all states plus update event.
enum ConnectionEvent {
  initialized,
  connecting,
  connected,
  disconnected,
  suspended,
  closing,
  closed,
  failed,

  /// Connection conditions changed without state change (RTN24).
  update,
}

extension ConnectionEventExtension on ConnectionEvent {
  /// Converts ConnectionState to ConnectionEvent.
  static ConnectionEvent fromState(ConnectionState state) {
    switch (state) {
      case ConnectionState.initialized:
        return ConnectionEvent.initialized;
      case ConnectionState.connecting:
        return ConnectionEvent.connecting;
      case ConnectionState.connected:
        return ConnectionEvent.connected;
      case ConnectionState.disconnected:
        return ConnectionEvent.disconnected;
      case ConnectionState.suspended:
        return ConnectionEvent.suspended;
      case ConnectionState.closing:
        return ConnectionEvent.closing;
      case ConnectionState.closed:
        return ConnectionEvent.closed;
      case ConnectionState.failed:
        return ConnectionEvent.failed;
    }
  }
}
