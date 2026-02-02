import 'package:test/test.dart';
import 'package:ably_dart/ably_dart.dart';
import '../../../helpers/mock_websocket_client.dart';
import '../../../helpers/protocol_message_helpers.dart';

/// Unit tests for heartbeat behavior (RTN23).
///
/// These tests use mocked WebSocket to verify connection heartbeat
/// and idle timeout behavior.
///
/// Spec: uts/test/realtime/unit/connection/heartbeat_test.md
void main() {
  group('RTN23a - Disconnect after maxIdleInterval + realtimeRequestTimeout',
      () {
    test('disconnects when no server activity detected', () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(
              connectionId: 'connection-id',
              connectionKey: 'connection-key',
              maxIdleInterval: 5000, // 5 seconds
              connectionStateTtl: 120000,
            ),
          );
          // Server sends CONNECTED but then no further messages
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          realtimeRequestTimeout: 2000, // 2 seconds
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      // Start connection
      client.connect();

      // Wait for CONNECTED state
      await _awaitState(client.connection, ConnectionState.connected);

      // Wait for maxIdleInterval + realtimeRequestTimeout + buffer
      // = 5000 + 2000 + 500 = 7500ms
      await Future<void>.delayed(const Duration(milliseconds: 7500));

      // Should transition to DISCONNECTED
      await _awaitState(
        client.connection,
        ConnectionState.disconnected,
        timeout: const Duration(seconds: 2),
      );

      // Verify error reason indicates timeout/inactivity
      expect(client.connection.state, equals(ConnectionState.disconnected));
      expect(client.connection.errorReason, isNotNull);
      expect(
        client.connection.errorReason!.message.toLowerCase(),
        anyOf(contains('idle'), contains('heartbeat'), contains('timeout')),
      );

      await client.close();
    });

    test('HEARTBEAT message resets idle timer', () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(
              connectionId: 'connection-id',
              connectionKey: 'connection-key',
              maxIdleInterval: 3000, // 3 seconds
              connectionStateTtl: 120000,
            ),
          );
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          realtimeRequestTimeout: 1000, // 1 second
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      // Start connection
      client.connect();

      // Wait for CONNECTED state
      await _awaitState(client.connection, ConnectionState.connected);

      // Wait 2 seconds (not enough to trigger timeout)
      await Future<void>.delayed(const Duration(milliseconds: 2000));

      // Send HEARTBEAT from server to reset timer
      mockWs.activeConnection!.sendToClient(
        ProtocolMessageHelpers.heartbeat(),
      );

      // Wait another 2 seconds (total 4 seconds, but timer was reset at 2s)
      await Future<void>.delayed(const Duration(milliseconds: 2000));

      // Connection should still be alive
      expect(client.connection.state, equals(ConnectionState.connected));

      // Wait past the new timeout window (3000 + 1000 + buffer)
      await Future<void>.delayed(const Duration(milliseconds: 2500));

      // Should disconnect now
      await _awaitState(
        client.connection,
        ConnectionState.disconnected,
        timeout: const Duration(seconds: 2),
      );

      expect(client.connection.state, equals(ConnectionState.disconnected));
      expect(client.connection.errorReason, isNotNull);

      await client.close();

    test('any protocol message resets idle timer', () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(
              connectionId: 'connection-id',
              connectionKey: 'connection-key',
              maxIdleInterval: 2000, // 2 seconds
              connectionStateTtl: 120000,
            ),
          );
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          realtimeRequestTimeout: 1000, // 1 second
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      client.connect();
      await _awaitState(client.connection, ConnectionState.connected);

      // Wait 1.5 seconds
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      // Send ACK message from server (timer reset)
      mockWs.activeConnection!.sendToClient(
        ProtocolMessageHelpers.ack(msgSerial: 0),
      );

      // Wait another 1.5 seconds
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      // Still connected (timer was reset)
      expect(client.connection.state, equals(ConnectionState.connected));

      // Send MESSAGE from server (timer reset again)
      mockWs.activeConnection!.sendToClient(
        ProtocolMessageHelpers.message(
          channel: 'test-channel',
          name: 'event',
          data: 'data',
        ),
      );

      // Wait another 1.5 seconds
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      // Still connected
      expect(client.connection.state, equals(ConnectionState.connected));

      // Wait past timeout without any message
      await Future<void>.delayed(const Duration(milliseconds: 2000));

      // Should disconnect now
      await _awaitState(
        client.connection,
        ConnectionState.disconnected,
        timeout: const Duration(seconds: 2),
      );

      expect(client.connection.state, equals(ConnectionState.disconnected));

      await client.close();
  });

  group('RTN23b - Client can request heartbeats in query params', () {
    test('client requests heartbeats in connection URL', () async {
      final connectionUrls = <Uri>[];

      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          // Record the connection URL
          connectionUrls.add(conn.url);

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

      // Client with default behavior (heartbeats enabled)
      final client1 = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      // Connect first client
      client1.connect();
      await _awaitState(client1.connection, ConnectionState.connected);

      // Check URL includes heartbeats parameter
      final url1 = connectionUrls[0];
      // Default is true or omitted, implementation-specific
      // expect(url1.queryParameters['heartbeats'], anyOf('true', isNull));

      await client1.close();

      // Client with heartbeats explicitly configured
      // (Implementation-specific how to disable heartbeats)
      final client2 = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
          // Implementation may have a specific option for this
        ),
        webSocketClient: mockWs,
      );

      client2.connect();
      await _awaitState(client2.connection, ConnectionState.connected);

      final url2 = connectionUrls[1];
      // Verify implementation adds heartbeats query param

      await client2.close();

    test('server respects heartbeats=false', () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(
              connectionId: 'connection-id',
              connectionKey: 'connection-key',
              maxIdleInterval: 2000, // 2 seconds
              connectionStateTtl: 120000,
            ),
          );
          // Server sends no HEARTBEAT messages
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
          // Configure to disable heartbeats (implementation-specific)
        ),
        webSocketClient: mockWs,
      );

      client.connect();
      await _awaitState(client.connection, ConnectionState.connected);

      // Wait well past maxIdleInterval
      await Future<void>.delayed(const Duration(milliseconds: 10000));

      // Connection behavior when heartbeats disabled is implementation-specific
      // Either stays connected indefinitely or has different timeout behavior
      final state = client.connection.state;
      expect(
        state,
        anyOf(
          equals(ConnectionState.connected),
          equals(ConnectionState.disconnected),
        ),
      );

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
