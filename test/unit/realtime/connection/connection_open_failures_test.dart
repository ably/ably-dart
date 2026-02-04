import 'package:clock/clock.dart';
import 'package:test/test.dart';
import 'package:ably_dart/ably_dart.dart';
import '../../../helpers/fake_timer_manager.dart';
import '../../../helpers/mock_http_client.dart';
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
          // WebSocket connects but server sends ERROR for invalid key
          conn.respondWithError(
            ProtocolMessageHelpers.error(
              code: 40005,
              statusCode: 400,
              message: 'Invalid key',
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

      // Start connection
      client.connect();

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

      mockWs.dispose();
    });
  });

  group('RTN14b - Token error during connection', () {
    test('token error with renewal capability retries', () async {
      var connectionAttemptCount = 0;
      var tokenRenewalCount = 0;

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

      // Use authCallback for token renewal
      final client = Realtime.forTesting(
        options: ClientOptions(
          authCallback: (params) async {
            tokenRenewalCount++;
            return TokenDetails(
              token: 'token_$tokenRenewalCount',
              expires: DateTime.now().millisecondsSinceEpoch + 3600000,
            );
          },
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      client.connect();

      // Wait for CONNECTED (should retry after token renewal)
      await _awaitState(client.connection, ConnectionState.connected);

      // Verify successfully connected after retry
      expect(client.connection.state, equals(ConnectionState.connected));

      // Connection was attempted twice
      expect(connectionAttemptCount, equals(2));
      expect(tokenRenewalCount, greaterThan(1)); // Initial + renewal

      mockWs.dispose();
    });

    test('token error without renewal transitions to FAILED', () async {
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

      // Use token directly (no way to renew - no key, authUrl, or authCallback)
      final client = Realtime.forTesting(
        options: ClientOptions(
          token: 'expired_token_string',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      client.connect();

      // RTN15h1: Should transition to FAILED since token cannot be renewed
      await _awaitState(client.connection, ConnectionState.failed);

      expect(client.connection.state, equals(ConnectionState.failed));
      expect(client.connection.errorReason, isNotNull);
      expect(client.connection.errorReason!.code, equals(40142));

      mockWs.dispose();
    });
  });

  group('RTN14c - Connection timeout', () {
    test('connection times out if no CONNECTED message', () async {
      final testClock = TestClock();
      final fakeTimers = FakeTimerManager(testClock);

      await withClock(testClock, () async {
        final mockWs = MockWebSocketClient(
          onConnectionAttempt: (conn) {
            // WebSocket connects but server never sends CONNECTED
            // This simulates an unresponsive server
            conn.respondWithSilence();
          },
        );

        // Mock HTTP client for connectivity check
        final mockHttp = MockHttpClient(
          onRequest: (request) {
            // Connectivity check succeeds
            request.respondWith(200, 'yes');
          },
        );

        final client = Realtime.forTesting(
          options: ClientOptions(
            key: 'appId.keyId:keySecret',
            realtimeRequestTimeout: 1000, // 1 second timeout
            autoConnect: false,
            fallbackHosts: [], // Disable fallbacks for simpler test
          ),
          webSocketClient: mockWs,
          timerManager: fakeTimers,
          httpClient: mockHttp,
        );

        client.connect();

        // Wait for CONNECTING state
        await _awaitState(client.connection, ConnectionState.connecting);

        // Advance time past the connection timeout
        fakeTimers.elapseTime(const Duration(milliseconds: 1100));

        // Allow async operations to complete
        await _pumpEventQueue();

        // Should transition to DISCONNECTED after timeout
        expect(client.connection.state, equals(ConnectionState.disconnected));
        expect(client.connection.errorReason, isNotNull);

        mockWs.dispose();
      });
    });
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

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          disconnectedRetryTimeout: 100, // Short timeout for testing
          autoConnect: false,
          fallbackHosts: [], // Disable fallback hosts for this test
        ),
        webSocketClient: mockWs,
      );

      client.connect();

      // Should transition to DISCONNECTED after first failure
      await _awaitState(client.connection, ConnectionState.disconnected);

      // Should reconnect automatically after retry timeout
      await _awaitState(
        client.connection,
        ConnectionState.connected,
        timeout: const Duration(seconds: 5),
      );

      expect(client.connection.state, equals(ConnectionState.connected));
      expect(connectionAttemptCount, equals(2));

      mockWs.dispose();
    });
  });

  group('RTN14e - DISCONNECTED to SUSPENDED after connectionStateTtl', () {
    test('transitions to SUSPENDED after prolonged disconnection', () async {
      final testClock = TestClock();
      final fakeTimers = FakeTimerManager(testClock);

      await withClock(testClock, () async {
        final mockWs = MockWebSocketClient(
          onConnectionAttempt: (conn) {
            // All connection attempts fail
            conn.respondWithRefused();
          },
        );

        final client = Realtime.forTesting(
          options: ClientOptions(
            key: 'appId.keyId:keySecret',
            disconnectedRetryTimeout: 1000, // 1 second retry
            autoConnect: false,
            fallbackHosts: [], // Disable fallbacks for simpler test
          ),
          webSocketClient: mockWs,
          timerManager: fakeTimers,
        );

        client.connect();

        // Should transition to DISCONNECTED
        await _awaitState(client.connection, ConnectionState.disconnected);

        // Advance time past connectionStateTtl (default 120 seconds)
        // The TTL timer is scheduled when entering DISCONNECTED
        fakeTimers.elapseTime(const Duration(seconds: 121));

        // Allow async operations to complete
        await Future<void>.delayed(Duration.zero);

        // Should transition to SUSPENDED after connectionStateTtl
        expect(client.connection.state, equals(ConnectionState.suspended));
        expect(client.connection.errorReason, isNotNull);

        mockWs.dispose();
      });
    });
  });

  group('RTN14f - SUSPENDED state retries indefinitely', () {
    test('continues retry attempts from SUSPENDED', () async {
      final testClock = TestClock();
      final fakeTimers = FakeTimerManager(testClock);

      await withClock(testClock, () async {
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

        // Mock HTTP client for connectivity check
        final mockHttp = MockHttpClient(
          onRequest: (request) {
            request.respondWith(200, 'yes');
          },
        );

        final client = Realtime.forTesting(
          options: ClientOptions(
            key: 'appId.keyId:keySecret',
            disconnectedRetryTimeout: 1000,
            suspendedRetryTimeout: 2000,
            autoConnect: false,
            fallbackHosts: [], // Disable fallbacks for simpler test
          ),
          webSocketClient: mockWs,
          timerManager: fakeTimers,
          httpClient: mockHttp,
        );

        client.connect();

        // Wait for DISCONNECTED state (first failure)
        await _awaitState(client.connection, ConnectionState.disconnected);

        // Advance time past connectionStateTtl to transition to SUSPENDED
        fakeTimers.elapseTime(const Duration(seconds: 121));
        await Future<void>.delayed(Duration.zero);

        // Should be in SUSPENDED
        expect(client.connection.state, equals(ConnectionState.suspended));

        // Advance time to trigger retry from SUSPENDED (suspendedRetryTimeout)
        fakeTimers.elapseTime(const Duration(seconds: 3));
        await _pumpEventQueue();

        // Second attempt fails (connectionAttemptCount < 3), goes back to DISCONNECTED
        // Since TTL has passed, it transitions to SUSPENDED and retries again
        if (client.connection.state != ConnectionState.connected) {
          fakeTimers.elapseTime(const Duration(seconds: 5));
          await _pumpEventQueue();
        }

        // The third attempt should succeed
        expect(client.connection.state, equals(ConnectionState.connected));
        expect(connectionAttemptCount, greaterThanOrEqualTo(3));

        mockWs.dispose();
      });
    });
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

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
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

      mockWs.dispose();
    });
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

/// Pumps the event queue to allow async operations to complete.
/// Used after advancing fake time to let scheduled callbacks run.
Future<void> _pumpEventQueue() async {
  await Future<void>.delayed(Duration.zero);
}
