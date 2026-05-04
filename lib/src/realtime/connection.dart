import 'dart:async';

import '../auth/token_details.dart';
import '../error/error_info.dart';
import 'connection_event.dart';
import 'connection_state.dart';
import 'connection_state_change.dart';

/// Manages the connection to Ably Realtime.
///
/// Spec: RTN
abstract class Connection {
  /// The current connection state.
  ///
  /// Spec: RTN4
  ConnectionState get state;

  /// Error information for the current state (if failed/suspended).
  ///
  /// Spec: RTN25
  ErrorInfo? get errorReason;

  /// The connection ID assigned by Ably.
  ///
  /// Null if not connected.
  ///
  /// Spec: RTN8
  String? get id;

  /// The connection key that can be used to resume a connection.
  ///
  /// Null if not connected.
  ///
  /// Spec: RTN9
  String? get key;

  /// The serial number of the last message received on this connection.
  ///
  /// Null if not connected.
  ///
  /// Spec: RTN10
  int? get serial;

  /// Listens to connection state changes.
  ///
  /// If [event] is provided, only emits changes matching that event.
  /// If [event] is null, emits all state changes.
  ///
  /// Spec: RTN4
  Stream<ConnectionStateChange> on([ConnectionEvent? event]);

  /// Calls the listener immediately with null if already in the target state,
  /// otherwise registers a one-time listener for that state.
  ///
  /// Spec: RTN26
  void whenState(
    ConnectionState targetState,
    void Function(ConnectionStateChange?) listener,
  );

  /// Explicitly initiates a connection to Ably.
  ///
  /// If already connected or connecting, this is a no-op.
  ///
  /// Spec: RTN11
  Future<void> connect();

  /// Closes the connection.
  ///
  /// Spec: RTN12
  Future<void> close();

  /// Performs in-band reauthorization after a new token has been obtained.
  ///
  /// Spec: RTC8
  Future<void> reauthorize(TokenDetails token);

  /// Sends a heartbeat ping and returns the round-trip duration.
  ///
  /// Spec: RTN13
  Future<Duration> ping();

  /// Returns a recovery key string that can be used to recover this connection.
  ///
  /// The recovery key contains the connectionKey, msgSerial, and a collection
  /// of channel name / channelSerial pairs for every currently attached channel.
  ///
  /// Returns null when in CLOSED, CLOSING, FAILED, or SUSPENDED states,
  /// or when the connection does not have a connectionKey.
  ///
  /// Spec: RTN16g, RTN16g1, RTN16g2
  String? createRecoveryKey();
}
