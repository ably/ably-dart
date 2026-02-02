import 'package:test/test.dart';
import 'package:ably_dart/ably_dart.dart';
import '../../../helpers/mock_websocket_client.dart';
import '../../../helpers/protocol_message_helpers.dart';

/// Unit tests for Connection#whenState (RTN26).
///
/// These tests verify the whenState convenience function that calls
/// listeners immediately if already in state, or waits for the state.
///
/// Spec: uts/test/realtime/unit/connection/when_state_test.md
void main() {
  group('RTN26a - whenState calls listener immediately if already in state',
      () {
    test('invokes callback immediately with null when already in target state',
        () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(
              connectionId: 'connection-id',
              connectionKey: 'connection-key',
              maxIdleInterval: 15000,
              connectionStateTtl: 120000,
            ),
          );
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      // Start connection
      client.connect();

      // Wait for CONNECTED state
      await _awaitState(client.connection, ConnectionState.connected);

      // Now call whenState for the current state
      var callbackInvoked = false;
      ConnectionStateChange? callbackArg;

      client.connection.whenState(ConnectionState.connected, (change) {
        callbackInvoked = true;
        callbackArg = change;
      });

      // Callback should be invoked immediately or very quickly
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Callback was invoked immediately
      expect(callbackInvoked, isTrue);

      // Callback was invoked with null argument (not a StateChange object)
      expect(callbackArg, isNull);

      await client.close();
    });
  });

  group('RTN26b - whenState waits for state if not already in it', () {
    test('waits for state transition when not currently in target state',
        () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(
              connectionId: 'connection-id',
              connectionKey: 'connection-key',
              maxIdleInterval: 15000,
              connectionStateTtl: 120000,
            ),
          );
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      // Connection is in INITIALIZED state
      expect(client.connection.state, equals(ConnectionState.initialized));

      // Set up whenState before connecting
      var callbackInvoked = false;
      ConnectionStateChange? callbackArg;

      client.connection.whenState(ConnectionState.connected, (change) {
        callbackInvoked = true;
        callbackArg = change;
      });

      // Callback should not be invoked yet
      expect(callbackInvoked, isFalse);

      // Start connection
      client.connect();

      // Wait for CONNECTED state
      await _awaitState(client.connection, ConnectionState.connected);

      // Give callback a moment to execute
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Callback was invoked after state transition
      expect(callbackInvoked, isTrue);

      // Callback was invoked with a ConnectionStateChange object (not null)
      expect(callbackArg, isNotNull);
      expect(
        callbackArg!.previous,
        anyOf(
          equals(ConnectionState.initialized),
          equals(ConnectionState.connecting),
        ),
      );
      expect(callbackArg!.current, equals(ConnectionState.connected));

      await client.close();
    });

    test('whenState only fires once per call', () async {
      var connectionAttemptCount = 0;

      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          connectionAttemptCount++;

          if (connectionAttemptCount == 1) {
            // First attempt: connect then we'll disconnect manually
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-id-1',
                connectionKey: 'connection-key-1',
                maxIdleInterval: 15000,
                connectionStateTtl: 120000,
              ),
            );
          } else {
            // Second attempt: connect again
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-id-2',
                connectionKey: 'connection-key-2',
                maxIdleInterval: 15000,
                connectionStateTtl: 120000,
              ),
            );
          }
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          disconnectedRetryTimeout: 100,
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      // Set up whenState listener
      var callbackCount = 0;

      client.connection.whenState(ConnectionState.connected, (change) {
        callbackCount++;
      });

      // Start connection
      client.connect();

      // Wait for first CONNECTED
      await _awaitState(client.connection, ConnectionState.connected);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Verify callback was invoked once
      expect(callbackCount, equals(1));

      // Force a disconnection
      mockWs.activeConnection!.close();

      // Wait for DISCONNECTED
      await _awaitState(
        client.connection,
        ConnectionState.disconnected,
        timeout: const Duration(seconds: 2),
      );

      // Wait for reconnection
      await _awaitState(
        client.connection,
        ConnectionState.connected,
        timeout: const Duration(seconds: 5),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Callback was still only invoked once (not again on reconnection)
      expect(callbackCount, equals(1));

      await client.close();
    });
  });

  group('RTN26 - Multiple whenState calls', () {
    test('multiple whenState listeners handled independently', () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(
              connectionId: 'connection-id',
              connectionKey: 'connection-key',
              maxIdleInterval: 15000,
              connectionStateTtl: 120000,
            ),
          );
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      // Set up multiple whenState listeners before connecting
      var callback1Invoked = false;
      var callback2Invoked = false;
      var callback3Invoked = false;

      client.connection.whenState(ConnectionState.connected, (change) {
        callback1Invoked = true;
      });

      client.connection.whenState(ConnectionState.connected, (change) {
        callback2Invoked = true;
      });

      client.connection.whenState(ConnectionState.connecting, (change) {
        callback3Invoked = true;
      });

      // Start connection
      client.connect();

      // Wait for CONNECTED state
      await _awaitState(client.connection, ConnectionState.connected);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // All whenState callbacks were invoked
      expect(callback1Invoked, isTrue);
      expect(callback2Invoked, isTrue);
      expect(callback3Invoked, isTrue);

      await client.close();
    });

    test('whenState with already-passed state does not fire', () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(
              connectionId: 'connection-id',
              connectionKey: 'connection-key',
              maxIdleInterval: 15000,
              connectionStateTtl: 120000,
            ),
          );
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      // Start connection
      client.connect();

      // Wait for CONNECTED state
      await _awaitState(client.connection, ConnectionState.connected);

      // Now call whenState for a past state (CONNECTING)
      var callbackInvoked = false;

      client.connection.whenState(ConnectionState.connecting, (change) {
        callbackInvoked = true;
      });

      // Wait to see if callback is invoked
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Callback should NOT be invoked (we're not in CONNECTING state anymore)
      expect(callbackInvoked, isFalse);

      await client.close();
    });
  });

  group('RTN26 - whenState with different states', () {
    test('whenState works correctly across different state transitions',
        () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          // Connection attempt fails
          conn.respondWithRefused();
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      // Set up whenState listeners for various states
      var initializedFired = false;
      var connectingFired = false;
      var disconnectedFired = false;

      client.connection.whenState(ConnectionState.initialized, (change) {
        initializedFired = true;
      });

      client.connection.whenState(ConnectionState.connecting, (change) {
        connectingFired = true;
      });

      client.connection.whenState(ConnectionState.disconnected, (change) {
        disconnectedFired = true;
      });

      // Initially in INITIALIZED
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Should fire immediately for current state
      expect(initializedFired, isTrue);
      expect(connectingFired, isFalse);
      expect(disconnectedFired, isFalse);

      // Start connection
      client.connect();

      // Wait for DISCONNECTED (connection will fail)
      await _awaitState(
        client.connection,
        ConnectionState.disconnected,
        timeout: const Duration(seconds: 5),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // All states were reached and callbacks invoked
      expect(initializedFired, isTrue);
      expect(connectingFired, isTrue);
      expect(disconnectedFired, isTrue);

      await client.close();
    });

    test('whenState for FAILED state', () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.error(
              code: 50000,
              statusCode: 500,
              message: 'Internal server error',
              channel: null,
            ),
          );
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      var failedFired = false;
      ConnectionStateChange? failedChange;

      client.connection.whenState(ConnectionState.failed, (change) {
        failedFired = true;
        failedChange = change;
      });

      // Start connection
      client.connect();

      // Wait for FAILED state
      await _awaitState(client.connection, ConnectionState.failed);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(failedFired, isTrue);
      expect(failedChange, isNotNull);
      expect(failedChange!.current, equals(ConnectionState.failed));

      await client.close();
    });

    test('whenState for CLOSED state', () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(
              connectionId: 'connection-id',
              connectionKey: 'connection-key',
              maxIdleInterval: 15000,
              connectionStateTtl: 120000,
            ),
          );
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      var closedFired = false;

      // Start connection first
      client.connect();
      await _awaitState(client.connection, ConnectionState.connected);

      // Now set up whenState for CLOSED
      client.connection.whenState(ConnectionState.closed, (change) {
        closedFired = true;
      });

      expect(closedFired, isFalse);

      // Close the connection
      await client.close();

      // Wait for CLOSED state
      await _awaitState(client.connection, ConnectionState.closed);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(closedFired, isTrue);
    });
  });
}

/// Helper function to wait for a connection state.
Future<void> _awaitState(
  Connection connection,
  ConnectionState targetState, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  if (connection.state == targetState) {
    return;
  }

  await connection
      .on()
      .firstWhere((change) => change.current == targetState)
      .timeout(timeout);
}
