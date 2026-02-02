import 'package:test/test.dart';
import 'package:ably_dart/ably_dart.dart';
import '../../../helpers/mock_websocket_client.dart';
import '../../../helpers/protocol_message_helpers.dart';

/// Unit tests for connection opening failures (RTN14).
///
/// These tests use mocked WebSocket to verify connection behavior
/// during the opening phase when various failures occur.
///
/// Spec: uts/test/realtime/unit/connection/connection_open_failures_test.md
void main() {
  group('RTN14a - Invalid API key causes FAILED state', () {
    test('connects with invalid key and receives ERROR', () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          // WebSocket connects successfully
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(
              connectionId: 'test-id',
              connectionKey: 'test-key',
            ),
          );
        },
        onMessageFromClient: (msg) {
          // When client sends any message, respond with error
          // In real scenario, server sends ERROR immediately after CONNECT
        },
      );

      // TODO: Install mock when dependency injection is available
      // installMock(mockWs);

      final client = Realtime(
        options: ClientOptions(
          key: 'invalid.key:secret',
          autoConnect: false,
        ),
      );

      // Start connection
      client.connect();

      // Wait for CONNECTING state
      await _awaitState(client.connection, ConnectionState.connecting);

      // TODO: Simulate ERROR from server
      // mockWs.sendErrorToClient(...)

      // Wait for FAILED state
      await _awaitState(client.connection, ConnectionState.failed);

      // Verify error reason is set
      expect(client.connection.state, equals(ConnectionState.failed));
      expect(client.connection.errorReason, isNotNull);
      expect(client.connection.errorReason!.code, equals(40005));
      expect(client.connection.errorReason!.statusCode, equals(400));

      // Connection ID/key not set
      expect(client.connection.id, isNull);
      expect(client.connection.key, isNull);
    }, skip: 'Requires WebSocket dependency injection');
  });

  group('RTN14b - Token error during connection', () {
    test('token error with renewal capability retries', () async {
      var tokenRequestCount = 0;
      var connectionAttemptCount = 0;

      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          connectionAttemptCount++;

          if (connectionAttemptCount == 1) {
            // First attempt: token error
            conn.respondWithError(
              ProtocolMessageHelpers.error(
                code: 40142,
                message: 'Token expired',
                statusCode: 401,
              ),
            );
          } else {
            // Second attempt: success after renewal
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-id',
                connectionKey: 'connection-key',
              ),
            );
          }
        },
      );

      // TODO: Mock HTTP client for token renewal
      // mockHttp.onRequest((req) => tokenRequestCount++; ...);

      final client = Realtime(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
      );

      client.connect();

      // Wait for CONNECTED (should retry after token renewal)
      await _awaitState(client.connection, ConnectionState.connected);

      // Verify successfully connected after retry
      expect(client.connection.state, equals(ConnectionState.connected));

      // Token should have been renewed (initial + renewal)
      // expect(tokenRequestCount, equals(2));

      // Connection was attempted twice
      expect(connectionAttemptCount, equals(2));
    }, skip: 'Requires WebSocket and HTTP dependency injection');

    test('token error without renewal transitions to DISCONNECTED', () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithError(
            ProtocolMessageHelpers.error(
              code: 40142,
              message: 'Token expired',
              statusCode: 401,
            ),
          );
        },
      );

      // Use token directly (no way to renew)
      final client = Realtime(
        options: ClientOptions(
          token: 'expired_token_string',
          autoConnect: false,
        ),
      );

      client.connect();

      // Wait for DISCONNECTED state (not FAILED, will retry)
      await _awaitState(client.connection, ConnectionState.disconnected);

      expect(client.connection.state, equals(ConnectionState.disconnected));
      expect(client.connection.errorReason, isNotNull);
      expect(client.connection.errorReason!.code, equals(40142));
    }, skip: 'Requires WebSocket dependency injection');
  });

  group('RTN14c - Connection timeout', () {
    test('connection times out if no CONNECTED message', () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          // WebSocket connects but server never sends CONNECTED
          // This simulates an unresponsive server
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(),
          );
          // TODO: Don't send CONNECTED message, let it timeout
        },
      );

      final client = Realtime(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          realtimeRequestTimeout: 1000, // 1 second timeout
          autoConnect: false,
        ),
      );

      client.connect();

      // Wait for CONNECTING state
      await _awaitState(client.connection, ConnectionState.connecting);

      // TODO: Advance fake time by 1100ms

      // Should transition to DISCONNECTED after timeout
      await _awaitState(client.connection, ConnectionState.disconnected,
          timeout: Duration(seconds: 2));

      expect(client.connection.state, equals(ConnectionState.disconnected));
      expect(client.connection.errorReason, isNotNull);
      // Error should indicate timeout
      expect(
        client.connection.errorReason!.message?.toLowerCase(),
        contains('timeout'),
      );
    }, skip: 'Requires timer mocking and WebSocket dependency injection');
  });

  group('RTN14d - Retry after recoverable failure', () {
    test('automatically retries after disconnectedRetryTimeout', () async {
      var connectionAttemptCount = 0;

      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          connectionAttemptCount++;

          if (connectionAttemptCount == 1) {
            // First attempt fails (network error)
            conn.respondWithRefused();
          } else {
            // Second attempt succeeds
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-id',
                connectionKey: 'connection-key',
              ),
            );
          }
        },
      );

      final client = Realtime(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          disconnectedRetryTimeout: 1000, // 1 second
          autoConnect: false,
        ),
      );

      client.connect();

      // Should transition to DISCONNECTED after first failure
      await _awaitState(client.connection, ConnectionState.disconnected);

      // TODO: Advance fake time by 1100ms to trigger retry

      // Should reconnect automatically
      await _awaitState(client.connection, ConnectionState.connected);

      expect(client.connection.state, equals(ConnectionState.connected));
      expect(connectionAttemptCount, equals(2));
    }, skip: 'Requires timer mocking and WebSocket dependency injection');
  });

  group('RTN14e - DISCONNECTED to SUSPENDED after connectionStateTtl', () {
    test('transitions to SUSPENDED after prolonged disconnection', () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          // All connection attempts fail
          conn.respondWithRefused();
        },
      );

      final client = Realtime(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          disconnectedRetryTimeout: 1000, // Retry every 1 second
          autoConnect: false,
        ),
      );

      // Note: connectionStateTtl comes from server in CONNECTED message
      // For this test, we assume a default of 5 seconds

      client.connect();

      // Should transition to DISCONNECTED
      await _awaitState(client.connection, ConnectionState.disconnected);

      // TODO: Advance fake time past connectionStateTtl (5 seconds)

      // Should transition to SUSPENDED
      await _awaitState(client.connection, ConnectionState.suspended);

      expect(client.connection.state, equals(ConnectionState.suspended));
      expect(client.connection.errorReason, isNotNull);
    }, skip: 'Requires timer mocking and WebSocket dependency injection');
  });

  group('RTN14f - SUSPENDED state retries indefinitely', () {
    test('continues retry attempts from SUSPENDED', () async {
      var connectionAttemptCount = 0;

      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          connectionAttemptCount++;

          if (connectionAttemptCount < 3) {
            // First 2 attempts fail
            conn.respondWithRefused();
          } else {
            // Third attempt succeeds
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-id',
                connectionKey: 'connection-key',
              ),
            );
          }
        },
      );

      final client = Realtime(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          disconnectedRetryTimeout: 500,
          suspendedRetryTimeout: 1000, // 1 second
          autoConnect: false,
        ),
      );

      client.connect();

      // Wait for SUSPENDED state
      await _awaitState(client.connection, ConnectionState.suspended);

      // TODO: Advance time to trigger SUSPENDED retries

      // Should reconnect successfully after multiple attempts
      await _awaitState(client.connection, ConnectionState.connected);

      expect(client.connection.state, equals(ConnectionState.connected));
      expect(connectionAttemptCount, greaterThanOrEqualTo(3));
    }, skip: 'Requires timer mocking and WebSocket dependency injection');
  });

  group('RTN14g - ERROR protocol message with empty channel', () {
    test('transitions to FAILED on connection-level ERROR', () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithError(
            ProtocolMessageHelpers.error(
              code: 50000,
              message: 'Internal server error',
              statusCode: 500,
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

      // Wait for FAILED state
      await _awaitState(client.connection, ConnectionState.failed);

      expect(client.connection.state, equals(ConnectionState.failed));
      expect(client.connection.errorReason, isNotNull);
      expect(client.connection.errorReason!.code, equals(50000));
      expect(client.connection.errorReason!.statusCode, equals(500));
      expect(
        client.connection.errorReason!.message,
        equals('Internal server error'),
      );
    }, skip: 'Requires WebSocket dependency injection');
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
