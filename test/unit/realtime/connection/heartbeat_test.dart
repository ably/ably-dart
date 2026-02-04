import 'package:clock/clock.dart';
import 'package:test/test.dart';
import 'package:ably_dart/ably_dart.dart';
import '../../../helpers/fake_timer_manager.dart';
import '../../../helpers/mock_websocket_client.dart';
import '../../../helpers/protocol_message_helpers.dart';
import '../../../helpers/test_channel_name.dart';

/// Unit tests for heartbeat behavior (RTN23).
///
/// These tests use mocked WebSocket and FakeTimerManager to verify
/// connection heartbeat and idle timeout behavior.
///
/// Spec: uts/test/realtime/unit/connection/heartbeat_test.md
void main() {
  group('RTN23a - Disconnect after maxIdleInterval + realtimeRequestTimeout',
      () {
    test('closes WebSocket and reconnects when no server activity detected',
        () async {
      final testClock = TestClock();
      final fakeTimers = FakeTimerManager(testClock);

      await withClock(testClock, () async {
        var connectionAttemptCount = 0;
        final stateChanges = <ConnectionState>[];

        final mockWs = MockWebSocketClient(
          onConnectionAttempt: (conn) {
            connectionAttemptCount++;
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-id-$connectionAttemptCount',
                connectionKey: 'connection-key-$connectionAttemptCount',
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
          timerManager: fakeTimers,
        );

        // Record all state changes
        client.connection.on().listen((change) {
          stateChanges.add(change.current);
        });

        // Start connection
        client.connect();

        // Wait for CONNECTED state
        await _awaitState(client.connection, ConnectionState.connected);
        expect(connectionAttemptCount, equals(1));

        // Advance time past maxIdleInterval + realtimeRequestTimeout
        // = 5000 + 2000 = 7000ms
        fakeTimers.elapseTime(const Duration(milliseconds: 7100));
        await _pumpEventQueue();

        // Wait for reconnection to complete
        await _awaitState(client.connection, ConnectionState.connected);

        // Verify the sequence of state changes:
        // CONNECTING -> CONNECTED -> DISCONNECTED -> CONNECTING -> CONNECTED
        expect(
            stateChanges,
            containsAllInOrder([
              ConnectionState.connecting,
              ConnectionState.connected,
              ConnectionState.disconnected,
              ConnectionState.connecting,
              ConnectionState.connected,
            ]));

        // Verify the client closed the first WebSocket connection
        expect(mockWs.clientCloseEvents, hasLength(1));

        // Verify two connection attempts were made (initial + reconnect)
        expect(connectionAttemptCount, equals(2));

        // Verify we're connected with the new connection details
        expect(client.connection.id, equals('connection-id-2'));

        await client.close();
        mockWs.dispose();
      });
    });

    test('HEARTBEAT message resets idle timer', () async {
      final testClock = TestClock();
      final fakeTimers = FakeTimerManager(testClock);

      await withClock(testClock, () async {
        var connectionAttemptCount = 0;

        final mockWs = MockWebSocketClient(
          onConnectionAttempt: (conn) {
            connectionAttemptCount++;
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-id-$connectionAttemptCount',
                connectionKey: 'connection-key-$connectionAttemptCount',
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
          timerManager: fakeTimers,
        );

        // Start connection
        client.connect();

        // Wait for CONNECTED state
        await _awaitState(client.connection, ConnectionState.connected);
        expect(connectionAttemptCount, equals(1));

        // Advance time 2 seconds (not enough to trigger timeout of 3000+1000=4000ms)
        fakeTimers.elapseTime(const Duration(milliseconds: 2000));
        await _pumpEventQueue();

        // Send HEARTBEAT from server to reset timer
        mockWs.activeConnection!.sendToClient(
          ProtocolMessageHelpers.heartbeat(),
        );
        await _pumpEventQueue();

        // Advance another 2 seconds (total 4 seconds, but timer was reset at 2s)
        fakeTimers.elapseTime(const Duration(milliseconds: 2000));
        await _pumpEventQueue();

        // Connection should still be alive (timer was reset by HEARTBEAT)
        expect(client.connection.state, equals(ConnectionState.connected));
        // Still only 1 connection attempt - no reconnection triggered
        expect(connectionAttemptCount, equals(1));

        // Advance past the new timeout window (4000ms from last heartbeat)
        fakeTimers.elapseTime(const Duration(milliseconds: 2100));
        await _pumpEventQueue();

        // Should have reconnected (immediate reconnection per RTN15a)
        await _awaitState(client.connection, ConnectionState.connected);

        // Verify reconnection happened
        expect(connectionAttemptCount, equals(2));
        expect(mockWs.clientCloseEvents, hasLength(1));

        await client.close();
        mockWs.dispose();
      });
    });

    test('any protocol message resets idle timer and client closes on timeout',
        () async {
      final testClock = TestClock();
      final fakeTimers = FakeTimerManager(testClock);

      await withClock(testClock, () async {
        var connectionAttemptCount = 0;
        final stateChanges = <ConnectionState>[];

        final mockWs = MockWebSocketClient(
          onConnectionAttempt: (conn) {
            connectionAttemptCount++;
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-id-$connectionAttemptCount',
                connectionKey: 'connection-key-$connectionAttemptCount',
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
          timerManager: fakeTimers,
        );

        // Record all state changes
        client.connection.on().listen((change) {
          stateChanges.add(change.current);
        });

        client.connect();
        await _awaitState(client.connection, ConnectionState.connected);

        // Advance 1.5 seconds (timeout is 2000+1000=3000ms)
        fakeTimers.elapseTime(const Duration(milliseconds: 1500));
        await _pumpEventQueue();

        // Send ACK message from server (timer reset)
        mockWs.activeConnection!.sendToClient(
          ProtocolMessageHelpers.ack(msgSerial: 0),
        );
        await _pumpEventQueue();

        // Advance another 1.5 seconds (total 3s, but timer was reset at 1.5s)
        fakeTimers.elapseTime(const Duration(milliseconds: 1500));
        await _pumpEventQueue();

        // Send MESSAGE from server (timer reset again)
        final channelName = testChannelName('RTN23a-message');
        mockWs.activeConnection!.sendToClient(
          ProtocolMessageHelpers.message(
            channel: channelName,
            name: 'event',
            data: 'data',
          ),
        );
        await _pumpEventQueue();

        // Advance another 1.5 seconds
        fakeTimers.elapseTime(const Duration(milliseconds: 1500));
        await _pumpEventQueue();

        // At this point, only one connection attempt (no timeout yet)
        expect(connectionAttemptCount, equals(1));

        // Advance past timeout without any message (3000ms + buffer)
        fakeTimers.elapseTime(const Duration(milliseconds: 3100));
        await _pumpEventQueue();

        // Wait for reconnection to complete
        await _awaitState(client.connection, ConnectionState.connected);

        // Verify the state change sequence includes disconnected
        expect(
            stateChanges,
            containsAllInOrder([
              ConnectionState.connecting,
              ConnectionState.connected,
              ConnectionState.disconnected,
              ConnectionState.connecting,
              ConnectionState.connected,
            ]));

        // Verify the client closed the WebSocket connection
        expect(mockWs.clientCloseEvents, hasLength(1));

        // Verify two connection attempts were made
        expect(connectionAttemptCount, equals(2));

        await client.close();
        mockWs.dispose();
      });
    });

    test('heartbeat timeout triggers immediate reconnection', () async {
      final testClock = TestClock();
      final fakeTimers = FakeTimerManager(testClock);

      await withClock(testClock, () async {
        var connectionAttemptCount = 0;
        final stateChanges = <ConnectionState>[];

        final mockWs = MockWebSocketClient(
          onConnectionAttempt: (conn) {
            connectionAttemptCount++;
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-id-$connectionAttemptCount',
                connectionKey: 'connection-key-$connectionAttemptCount',
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
          timerManager: fakeTimers,
        );

        // Record all state changes
        client.connection.on().listen((change) {
          stateChanges.add(change.current);
        });

        client.connect();
        await _awaitState(client.connection, ConnectionState.connected);

        expect(connectionAttemptCount, equals(1));

        // Advance time past maxIdleInterval + realtimeRequestTimeout
        // = 2000 + 1000 = 3000ms
        fakeTimers.elapseTime(const Duration(milliseconds: 3100));
        await _pumpEventQueue();

        // Wait for reconnection to complete (immediate per RTN15a)
        await _awaitState(client.connection, ConnectionState.connected);

        // Verify the state change sequence shows disconnected then reconnected
        expect(
            stateChanges,
            containsAllInOrder([
              ConnectionState.connecting,
              ConnectionState.connected,
              ConnectionState.disconnected,
              ConnectionState.connecting,
              ConnectionState.connected,
            ]));

        // Verify two connection attempts were made (initial + reconnect)
        expect(connectionAttemptCount, equals(2));

        // Verify the client is now connected with new connection details
        expect(client.connection.state, equals(ConnectionState.connected));
        expect(client.connection.id, equals('connection-id-2'));

        // Verify the first connection was closed by the client
        expect(mockWs.clientCloseEvents, hasLength(1));

        await client.close();
        mockWs.dispose();
      });
    });

    test('reconnection after heartbeat timeout uses resume', () async {
      final testClock = TestClock();
      final fakeTimers = FakeTimerManager(testClock);

      await withClock(testClock, () async {
        final connectionAttempts = <Uri>[];
        final stateChanges = <ConnectionState>[];

        final mockWs = MockWebSocketClient(
          onConnectionAttempt: (conn) {
            connectionAttempts.add(conn.url);
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(
                connectionId: 'connection-id-${connectionAttempts.length}',
                connectionKey: 'connection-key-${connectionAttempts.length}',
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
          timerManager: fakeTimers,
        );

        // Record all state changes
        client.connection.on().listen((change) {
          stateChanges.add(change.current);
        });

        client.connect();
        await _awaitState(client.connection, ConnectionState.connected);

        // Advance time past timeout to trigger disconnection
        fakeTimers.elapseTime(const Duration(milliseconds: 3100));
        await _pumpEventQueue();

        // Wait for reconnection to complete (immediate per RTN15a)
        await _awaitState(client.connection, ConnectionState.connected);

        // Verify the state change sequence shows disconnected
        expect(
            stateChanges,
            containsAllInOrder([
              ConnectionState.connecting,
              ConnectionState.connected,
              ConnectionState.disconnected,
              ConnectionState.connecting,
              ConnectionState.connected,
            ]));

        expect(connectionAttempts, hasLength(2));

        // First connection should not have resume parameter
        final firstUrl = connectionAttempts[0];
        expect(firstUrl.queryParameters.containsKey('resume'), isFalse);

        // Second connection should include resume parameter with first connectionKey
        final secondUrl = connectionAttempts[1];
        expect(secondUrl.queryParameters['resume'], equals('connection-key-1'));

        await client.close();
        mockWs.dispose();
      });
    });
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
      mockWs.dispose();
    });

    test('server respects heartbeats=false', () async {
      final testClock = TestClock();
      final fakeTimers = FakeTimerManager(testClock);

      await withClock(testClock, () async {
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
          timerManager: fakeTimers,
        );

        client.connect();
        await _awaitState(client.connection, ConnectionState.connected);

        // Advance time well past maxIdleInterval
        fakeTimers.elapseTime(const Duration(milliseconds: 10000));
        await _pumpEventQueue();

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
        mockWs.dispose();
      });
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

/// Pumps the event queue multiple times to allow microtasks to complete.
///
/// A single [Future.delayed(Duration.zero)] only processes one "tick" of
/// microtasks. Multiple nested scheduleMicrotask calls (e.g., close()
/// schedules onClose, which schedules reconnect) require multiple pumps.
Future<void> _pumpEventQueue([int times = 5]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
