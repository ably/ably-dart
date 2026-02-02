import 'package:test/test.dart';
import 'package:ably_dart/ably_dart.dart';
import '../../../helpers/mock_websocket_client.dart';
import '../../../helpers/protocol_message_helpers.dart';

/// Unit tests for connection failures when connected (RTN15).
///
/// These tests use mocked WebSocket to verify connection behavior
/// when failures occur after the connection is established.
///
/// Spec: uts/test/realtime/unit/connection/connection_failures_test.md
void main() {
  group('RTN15h1 - DISCONNECTED with token error, no renewal', () {
    test('transitions to FAILED when token cannot be renewed', () async {
      late MockWebSocketConnection wsConnection;

      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(
              connectionId: 'connection-id',
              connectionKey: 'connection-key',
            ),
          );
        },
      );

      // Use token directly (no way to renew)
      final client = Realtime(
        options: ClientOptions(
          token: 'some_token_string',
          autoConnect: false,
        ),
      );

      client.connect();
      await _awaitState(client.connection, ConnectionState.connected);

      // TODO: Get WebSocket connection from mock to send DISCONNECTED
      // wsConnection.sendToClient(ProtocolMessageHelpers.disconnected(...));

      // Should transition to FAILED
      await _awaitState(client.connection, ConnectionState.failed);

      expect(client.connection.state, equals(ConnectionState.failed));
      expect(client.connection.errorReason, isNotNull);
      expect(client.connection.errorReason!.code, equals(40142));
    }, skip: 'Requires WebSocket dependency injection and message injection');
  });

  group('RTN15h2 - DISCONNECTED with token error, renewable', () {
    test('renews token and resumes connection', () async {
      var tokenRequestCount = 0;
      var connectionAttemptCount = 0;

      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          connectionAttemptCount++;

          if (connectionAttemptCount == 1) {
            // First connection succeeds
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-1',
                connectionKey: 'key-1',
              ),
            );
          } else {
            // Resume after token renewal succeeds
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-1', // Same ID = resumed
                connectionKey: 'key-1-renewed',
              ),
            );
          }
        },
      );

      // TODO: Mock HTTP for token renewal

      final client = Realtime(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
      );

      client.connect();
      await _awaitState(client.connection, ConnectionState.connected);

      final firstConnectionId = client.connection.id;
      final firstConnectionKey = client.connection.key;

      // TODO: Send DISCONNECTED with token error from server

      // Should transition to CONNECTING (to renew and resume)
      await _awaitState(client.connection, ConnectionState.connecting);

      // Should reconnect with renewed token
      await _awaitState(client.connection, ConnectionState.connected);

      expect(client.connection.state, equals(ConnectionState.connected));
      // expect(tokenRequestCount, equals(2)); // Initial + renewal
      expect(client.connection.id, equals(firstConnectionId)); // Resumed
      expect(
          client.connection.key, isNot(equals(firstConnectionKey))); // Updated
    }, skip: 'Requires WebSocket and HTTP dependency injection');

    test('transitions to DISCONNECTED if renewal fails', () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(
              connectionId: 'connection-1',
              connectionKey: 'key-1',
            ),
          );
        },
      );

      // TODO: Mock HTTP to return token renewal error

      final client = Realtime(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
      );

      client.connect();
      await _awaitState(client.connection, ConnectionState.connected);

      // TODO: Send DISCONNECTED with token error

      await _awaitState(client.connection, ConnectionState.connecting);

      // Renewal fails, should go to DISCONNECTED
      await _awaitState(client.connection, ConnectionState.disconnected);

      expect(client.connection.state, equals(ConnectionState.disconnected));
      expect(client.connection.errorReason, isNotNull);
    }, skip: 'Requires WebSocket and HTTP dependency injection');
  });

  group('RTN15h3 - DISCONNECTED with non-token error', () {
    test('immediately resumes connection', () async {
      var connectionAttemptCount = 0;
      final capturedUrls = <Uri>[];

      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          connectionAttemptCount++;
          capturedUrls.add(conn.url);

          if (connectionAttemptCount == 1) {
            // First connection succeeds
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-1',
                connectionKey: 'key-1',
              ),
            );
          } else {
            // Resume succeeds
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-1', // Same ID = resumed
                connectionKey: 'key-1',
              ),
            );
          }
        },
      );

      final client = Realtime(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
      );

      client.connect();
      await _awaitState(client.connection, ConnectionState.connected);

      final originalConnectionId = client.connection.id;

      // TODO: Send DISCONNECTED with non-token error

      await _awaitState(client.connection, ConnectionState.connecting);
      await _awaitState(client.connection, ConnectionState.connected);

      expect(client.connection.state, equals(ConnectionState.connected));
      expect(client.connection.id, equals(originalConnectionId));
      expect(connectionAttemptCount, equals(2));

      // Second connection should include resume parameter
      expect(capturedUrls[1].queryParameters['resume'], equals('key-1'));
    }, skip: 'Requires WebSocket dependency injection and message injection');
  });

  group('RTN15j - ERROR with empty channel when CONNECTED', () {
    test('transitions to FAILED on connection-level ERROR', () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(
              connectionId: 'connection-id',
              connectionKey: 'connection-key',
            ),
          );
        },
      );

      final client = Realtime(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
      );

      client.connect();
      await _awaitState(client.connection, ConnectionState.connected);

      // TODO: Send ERROR with empty channel from server

      await _awaitState(client.connection, ConnectionState.failed);

      expect(client.connection.state, equals(ConnectionState.failed));
      expect(client.connection.errorReason, isNotNull);
      expect(client.connection.errorReason!.code, equals(50000));
    }, skip: 'Requires WebSocket dependency injection and message injection');
  });

  group('RTN15a - Unexpected transport disconnect', () {
    test('triggers resume attempt', () async {
      var connectionAttemptCount = 0;

      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          connectionAttemptCount++;

          if (connectionAttemptCount == 1) {
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-1',
                connectionKey: 'key-1',
              ),
            );
          } else {
            // Resume succeeds
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-1',
                connectionKey: 'key-1',
              ),
            );
          }
        },
      );

      final client = Realtime(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
      );

      client.connect();
      await _awaitState(client.connection, ConnectionState.connected);

      final originalConnectionId = client.connection.id;

      // TODO: Simulate unexpected disconnect (no protocol message)

      await _awaitState(client.connection, ConnectionState.disconnected);
      await _awaitState(client.connection, ConnectionState.connecting);
      await _awaitState(client.connection, ConnectionState.connected);

      expect(client.connection.state, equals(ConnectionState.connected));
      expect(client.connection.id, equals(originalConnectionId)); // Resumed
      expect(connectionAttemptCount, equals(2));
    },
        skip:
            'Requires WebSocket dependency injection and disconnect simulation');
  });

  group('RTN15b, RTN15c6 - Successful resume', () {
    test('resumes with same connectionId', () async {
      var connectionAttemptCount = 0;
      final capturedUrls = <Uri>[];

      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          connectionAttemptCount++;
          capturedUrls.add(conn.url);

          if (connectionAttemptCount == 1) {
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-1',
                connectionKey: 'key-1',
              ),
            );
          } else {
            // Resume succeeds (same connectionId)
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-1',
                connectionKey: 'key-1-updated',
              ),
            );
          }
        },
      );

      final client = Realtime(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
      );

      client.connect();
      await _awaitState(client.connection, ConnectionState.connected);

      expect(client.connection.id, equals('connection-1'));

      // TODO: Force disconnect

      await _awaitState(client.connection, ConnectionState.connected);

      // Connection resumed (same ID)
      expect(client.connection.id, equals('connection-1'));

      // Connection key was updated (RTN15e)
      expect(client.connection.key, equals('key-1-updated'));

      // Second connection included resume parameter (RTN15b1)
      expect(capturedUrls[1].queryParameters['resume'], equals('key-1'));
      expect(connectionAttemptCount, equals(2));
    },
        skip:
            'Requires WebSocket dependency injection and disconnect simulation');
  });

  group('RTN15c7 - Failed resume', () {
    test('handles new connectionId indicating failed resume', () async {
      var connectionAttemptCount = 0;

      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          connectionAttemptCount++;

          if (connectionAttemptCount == 1) {
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-1',
                connectionKey: 'key-1',
              ),
            );
          } else {
            // Resume failed (new connectionId + error)
            // TODO: Send CONNECTED with error field
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-2', // Different ID
                connectionKey: 'key-2',
              ),
            );
          }
        },
      );

      final client = Realtime(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
      );

      client.connect();
      await _awaitState(client.connection, ConnectionState.connected);

      final originalConnectionId = client.connection.id;

      // TODO: Force disconnect

      await _awaitState(client.connection, ConnectionState.connected);

      // New connection (different ID)
      expect(client.connection.id, equals('connection-2'));
      expect(client.connection.id, isNot(equals(originalConnectionId)));

      // Connection key updated
      expect(client.connection.key, equals('key-2'));

      // Error reason set (indicates why resume failed)
      // expect(client.connection.errorReason, isNotNull);
      // expect(client.connection.errorReason!.code, equals(80008));

      // Connection is still CONNECTED
      expect(client.connection.state, equals(ConnectionState.connected));
    },
        skip:
            'Requires WebSocket dependency injection and disconnect simulation');
  });

  group('RTN15g - Connection state cleared after connectionStateTtl', () {
    test('makes fresh connection after TTL expires', () async {
      var connectionAttemptCount = 0;
      final capturedUrls = <Uri>[];

      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          connectionAttemptCount++;
          capturedUrls.add(conn.url);

          if (connectionAttemptCount == 1) {
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-1',
                connectionKey: 'key-1',
                connectionStateTtl: 5000, // 5 seconds TTL
              ),
            );
          } else {
            // Fresh connection (no resume)
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-2',
                connectionKey: 'key-2',
              ),
            );
          }
        },
      );

      final client = Realtime(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          disconnectedRetryTimeout: 1000,
          autoConnect: false,
        ),
      );

      client.connect();
      await _awaitState(client.connection, ConnectionState.connected);

      final originalConnectionId = client.connection.id;

      // TODO: Force disconnect
      // TODO: Advance time past connectionStateTtl (6 seconds)
      // TODO: Trigger reconnection

      await _awaitState(client.connection, ConnectionState.connected);

      // New connection (different ID, not resumed)
      expect(client.connection.id, equals('connection-2'));
      expect(client.connection.id, isNot(equals(originalConnectionId)));

      // Second connection did NOT include resume parameter
      expect(capturedUrls[1].queryParameters.containsKey('resume'), isFalse);

      // Fresh connection key
      expect(client.connection.key, equals('key-2'));
    },
        skip:
            'Requires WebSocket dependency injection, disconnect simulation, and timer mocking');
  });

  group('RTN15c5 - ERROR with token error during resume', () {
    test('renews token and retries', () async {
      var tokenRequestCount = 0;
      var connectionAttemptCount = 0;

      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          connectionAttemptCount++;

          if (connectionAttemptCount == 1) {
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-1',
                connectionKey: 'key-1',
              ),
            );
          } else if (connectionAttemptCount == 2) {
            // Resume attempt fails with token error
            conn.respondWithError(
              ProtocolMessageHelpers.error(
                code: 40142,
                message: 'Token expired',
                statusCode: 401,
              ),
            );
          } else {
            // Retry with renewed token succeeds
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-2',
                connectionKey: 'key-2',
              ),
            );
          }
        },
      );

      // TODO: Mock HTTP for token renewal

      final client = Realtime(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
      );

      client.connect();
      await _awaitState(client.connection, ConnectionState.connected);

      // TODO: Force disconnect (will trigger resume attempt with token error)

      // Wait for final CONNECTED (after token renewal)
      await _awaitState(client.connection, ConnectionState.connected);

      expect(client.connection.state, equals(ConnectionState.connected));
      // expect(tokenRequestCount, equals(2)); // Initial + renewal
      expect(connectionAttemptCount, equals(3));
    },
        skip:
            'Requires WebSocket and HTTP dependency injection, disconnect simulation');
  });

  group('RTN15c4 - ERROR with fatal error during resume', () {
    test('transitions to FAILED on fatal error', () async {
      var connectionAttemptCount = 0;

      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          connectionAttemptCount++;

          if (connectionAttemptCount == 1) {
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-1',
                connectionKey: 'key-1',
              ),
            );
          } else {
            // Resume attempt fails with fatal error
            conn.respondWithError(
              ProtocolMessageHelpers.error(
                code: 50000,
                message: 'Internal server error',
                statusCode: 500,
              ),
            );
          }
        },
      );

      final client = Realtime(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
      );

      client.connect();
      await _awaitState(client.connection, ConnectionState.connected);

      // TODO: Force disconnect (will trigger resume with fatal error)

      await _awaitState(client.connection, ConnectionState.failed);

      expect(client.connection.state, equals(ConnectionState.failed));
      expect(client.connection.errorReason, isNotNull);
      expect(client.connection.errorReason!.code, equals(50000));

      // Only two connection attempts (no retry after fatal error)
      expect(connectionAttemptCount, equals(2));
    },
        skip:
            'Requires WebSocket dependency injection and disconnect simulation');
  });
}

/// Waits for connection to reach the specified state.
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
