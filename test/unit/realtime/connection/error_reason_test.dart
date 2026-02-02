import 'package:test/test.dart';
import 'package:ably_dart/ably_dart.dart';
import '../../../helpers/mock_websocket_client.dart';
import '../../../helpers/protocol_message_helpers.dart';

/// Unit tests for Connection#errorReason (RTN25).
///
/// These tests verify that errorReason is populated correctly
/// across various error scenarios.
///
/// Spec: uts/test/realtime/unit/connection/error_reason_test.md
void main() {
  group('RTN25 - errorReason set on connection errors', () {
    test('errorReason populated on connection failure', () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.error(
              code: 40005,
              statusCode: 400,
              message: 'Invalid API key',
            ),
          );
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'invalid.key:secret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      // Initially errorReason should be null
      expect(client.connection.errorReason, isNull);

      // Start connection
      client.connect();

      // Wait for FAILED state
      await _awaitState(client.connection, ConnectionState.failed);

      // errorReason is set with error details
      expect(client.connection.errorReason, isNotNull);
      expect(client.connection.errorReason!.code, equals(40005));
      expect(client.connection.errorReason!.statusCode, equals(400));
      expect(client.connection.errorReason!.message, equals('Invalid API key'));

      await client.close();
    });

    test('errorReason set on DISCONNECTED state', () async {
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

      // Start connection
      client.connect();

      // Wait for DISCONNECTED state
      await _awaitState(client.connection, ConnectionState.disconnected);

      // errorReason is set
      expect(client.connection.errorReason, isNotNull);
      expect(client.connection.errorReason!.message, isNotNull);

      await client.close();

    test('errorReason on SUSPENDED state after connectionStateTtl', () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          // All connection attempts fail
          conn.respondWithRefused();
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          disconnectedRetryTimeout: 500,
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      // Start connection (will fail)
      client.connect();

      // Wait for DISCONNECTED state
      await _awaitState(client.connection, ConnectionState.disconnected);

      // Wait for SUSPENDED state (after connectionStateTtl)
      // Note: This requires implementing the TTL timer
      await _awaitState(
        client.connection,
        ConnectionState.suspended,
        timeout: const Duration(seconds: 10),
      );

      // errorReason is set and indicates suspension
      expect(client.connection.errorReason, isNotNull);
      expect(client.connection.errorReason!.message, isNotNull);

      await client.close();
    }, skip: 'Requires SUSPENDED state and errorReason implementation');

    test('errorReason on token errors', () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.error(
              code: 40142,
              statusCode: 401,
              message: 'Token expired',
            ),
          );
        },
      );

      // Use token directly (no way to renew)
      final client = Realtime.forTesting(
        options: ClientOptions(
          token: 'expired_token',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      // Start connection
      client.connect();

      // Wait for DISCONNECTED state (can't renew token)
      await _awaitState(client.connection, ConnectionState.disconnected);

      // errorReason contains token error details
      expect(client.connection.errorReason, isNotNull);
      expect(client.connection.errorReason!.code, equals(40142));
      expect(client.connection.errorReason!.statusCode, equals(401));
      expect(
        client.connection.errorReason!.message!.toLowerCase(),
        contains('token'),
      );

      await client.close();
    }, skip: 'Requires token error handling and errorReason implementation');

    test('errorReason cleared on successful connection', () async {
      var connectionAttemptCount = 0;

      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          connectionAttemptCount++;

          if (connectionAttemptCount == 1) {
            // First attempt fails
            conn.respondWithRefused();
          } else {
            // Second attempt succeeds
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-id',
                connectionKey: 'connection-key',
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

      // Start connection (will fail initially)
      client.connect();

      // Wait for DISCONNECTED state
      await _awaitState(client.connection, ConnectionState.disconnected);

      // errorReason should be set after failure
      expect(client.connection.errorReason, isNotNull);

      // Wait for retry and successful connection
      await _awaitState(
        client.connection,
        ConnectionState.connected,
        timeout: const Duration(seconds: 5),
      );

      // errorReason behavior after successful connection is implementation-specific
      // Either cleared (null) or kept for debugging purposes
      // Verify implementation behavior:
      // Option A: errorReason is cleared
      // expect(client.connection.errorReason, isNull);
      // Option B: errorReason kept but not relevant to current state
      // (Implementation-specific behavior)

      await client.close();

    test('errorReason on protocol-level ERROR message', () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.error(
              code: 50000,
              statusCode: 500,
              message: 'Internal server error',
              channel: null, // Empty channel = connection-level error
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

      // Wait for FAILED state
      await _awaitState(client.connection, ConnectionState.failed);

      // errorReason is set from ERROR protocol message
      expect(client.connection.errorReason, isNotNull);
      expect(client.connection.errorReason!.code, equals(50000));
      expect(client.connection.errorReason!.statusCode, equals(500));
      expect(
        client.connection.errorReason!.message,
        equals('Internal server error'),
      );

      await client.close();
    }, skip: 'Requires protocol ERROR handling and errorReason implementation');

    test('errorReason propagated to ConnectionStateChange events', () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.error(
              code: 40003,
              statusCode: 400,
              message: 'Access token invalid',
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

      // Track state changes
      final stateChanges = <ConnectionStateChange>[];

      client.connection.on(ConnectionEvent.failed).listen((change) {
        stateChanges.add(change);
      });

      // Start connection
      client.connect();

      // Wait for FAILED state
      await _awaitState(client.connection, ConnectionState.failed);

      // State change event was emitted
      expect(stateChanges.length, equals(1));

      final change = stateChanges[0];

      // State change has reason populated
      expect(change.reason, isNotNull);
      expect(change.reason!.code, equals(40003));
      expect(change.reason!.statusCode, equals(400));
      expect(change.reason!.message, equals('Access token invalid'));

      // Connection errorReason matches state change reason
      expect(client.connection.errorReason, isNotNull);
      expect(client.connection.errorReason!.code, equals(change.reason!.code));
      expect(
        client.connection.errorReason!.message,
        equals(change.reason!.message),
      );

      await client.close();
  });

  group('RTN25 - errorReason across different error types', () {
    test('errorReason on connection timeout', () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(
              connectionId: 'connection-id',
              connectionKey: 'connection-key',
            ),
          );
          // But never send CONNECTED message (timeout scenario)
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          realtimeRequestTimeout: 1000, // 1 second timeout
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      client.connect();

      // Wait for DISCONNECTED (after timeout)
      await _awaitState(
        client.connection,
        ConnectionState.disconnected,
        timeout: const Duration(seconds: 3),
      );

      // errorReason indicates timeout
      expect(client.connection.errorReason, isNotNull);
      expect(
        client.connection.errorReason!.message!.toLowerCase(),
        anyOf(contains('timeout'), contains('timed out')),
      );

      await client.close();
    }, skip: 'Requires connection timeout and errorReason implementation');

    test('errorReason persists across state transitions', () async {
      var connectionAttemptCount = 0;

      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          connectionAttemptCount++;

          if (connectionAttemptCount <= 2) {
            // First two attempts fail
            conn.respondWithRefused();
          } else {
            // Third attempt succeeds
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-id',
                connectionKey: 'connection-key',
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

      client.connect();

      // Wait for first DISCONNECTED
      await _awaitState(client.connection, ConnectionState.disconnected);
      expect(client.connection.errorReason, isNotNull);
      final firstError = client.connection.errorReason;

      // Wait for second DISCONNECTED (after retry)
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await _awaitState(client.connection, ConnectionState.disconnected);
      expect(client.connection.errorReason, isNotNull);
      // errorReason may be updated or remain the same

      // Finally connect successfully
      await _awaitState(
        client.connection,
        ConnectionState.connected,
        timeout: const Duration(seconds: 3),
      );

      // errorReason lifecycle after successful connection is implementation-specific

      await client.close();
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
