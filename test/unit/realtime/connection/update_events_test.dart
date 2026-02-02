import 'package:test/test.dart';
import 'package:ably_dart/ably_dart.dart';
import '../../../helpers/mock_websocket_client.dart';
import '../../../helpers/protocol_message_helpers.dart';

/// Unit tests for UPDATE events (RTN24).
///
/// These tests verify that receiving CONNECTED while already CONNECTED
/// emits UPDATE events (not CONNECTED events) and updates connection details.
///
/// Spec: uts/test/realtime/unit/connection/update_events_test.md
void main() {
  group('RTN24 - CONNECTED message while already CONNECTED emits UPDATE', () {
    test('emits UPDATE event, not CONNECTED event', () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(
              connectionId: 'connection-id-1',
              connectionKey: 'connection-key-1',
              maxIdleInterval: 15000,
              connectionStateTtl: 120000,
              clientId: 'client-123',
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

      // Track events
      final connectedEvents = <ConnectionStateChange>[];
      final updateEvents = <ConnectionStateChange>[];

      client.connection.on(ConnectionEvent.connected).listen((change) {
        connectedEvents.add(change);
      });

      client.connection.on(ConnectionEvent.update).listen((change) {
        updateEvents.add(change);
      });

      // Start connection
      client.connect();

      // Wait for initial CONNECTED state
      await _awaitState(client.connection, ConnectionState.connected);

      // Verify initial connection
      expect(connectedEvents.length, equals(1));
      expect(updateEvents.length, equals(0));

      // Server sends another CONNECTED message (e.g., after reauth)
      mockWs.activeConnection!.sendToClient(
        ProtocolMessageHelpers.connected(
          connectionId: 'connection-id-2',
          connectionKey: 'connection-key-2',
          maxIdleInterval: 20000, // Different value
          connectionStateTtl: 120000,
          clientId: 'client-123',
        ),
      );

      // Wait for event to be processed
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // State remains CONNECTED
      expect(client.connection.state, equals(ConnectionState.connected));

      // No additional CONNECTED event was emitted
      expect(connectedEvents.length, equals(1));

      // UPDATE event was emitted
      expect(updateEvents.length, equals(1));

      // UPDATE event has correct structure
      final updateChange = updateEvents[0];
      expect(updateChange.previous, equals(ConnectionState.connected));
      expect(updateChange.current, equals(ConnectionState.connected));
      expect(updateChange.reason, isNull); // No error in this case

      // Connection details were updated
      expect(client.connection.id, equals('connection-id-2'));
      expect(client.connection.key, equals('connection-key-2'));

      await client.close();
    });

    test('UPDATE event includes error reason when present', () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(
              connectionId: 'connection-id-1',
              connectionKey: 'connection-key-1',
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

      // Track UPDATE events
      final updateEvents = <ConnectionStateChange>[];

      client.connection.on(ConnectionEvent.update).listen((change) {
        updateEvents.add(change);
      });

      // Start connection
      client.connect();
      await _awaitState(client.connection, ConnectionState.connected);

      // Server sends CONNECTED with error (e.g., token renewed due to expiry)
      mockWs.activeConnection!.sendToClient(
        ProtocolMessageHelpers.connected(
          connectionId: 'connection-id-2',
          connectionKey: 'connection-key-2',
          maxIdleInterval: 15000,
          connectionStateTtl: 120000,
          error: ErrorInfo(
            code: 40142,
            statusCode: 401,
            message: 'Token expired; renewed automatically',
          ),
        ),
      );

      // Wait for event to be processed
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // UPDATE event was emitted
      expect(updateEvents.length, equals(1));

      // UPDATE event has error reason
      final updateChange = updateEvents[0];
      expect(updateChange.previous, equals(ConnectionState.connected));
      expect(updateChange.current, equals(ConnectionState.connected));
      expect(updateChange.reason, isNotNull);
      expect(updateChange.reason!.code, equals(40142));
      expect(updateChange.reason!.statusCode, equals(401));
      expect(updateChange.reason!.message, contains('Token expired'));

      await client.close();
    });

    test('connectionDetails override stored details', () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(
              connectionId: 'connection-id-1',
              connectionKey: 'connection-key-1',
              maxIdleInterval: 10000,
              connectionStateTtl: 60000,
              maxMessageSize: 16384,
              serverId: 'server-1',
              clientId: 'client-original',
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
      await _awaitState(client.connection, ConnectionState.connected);

      // Verify initial connection details
      expect(client.connection.id, equals('connection-id-1'));
      expect(client.connection.key, equals('connection-key-1'));

      // Server sends new CONNECTED with different details
      mockWs.activeConnection!.sendToClient(
        ProtocolMessageHelpers.connected(
          connectionId: 'connection-id-2',
          connectionKey: 'connection-key-2',
          maxIdleInterval: 20000, // Changed
          connectionStateTtl: 120000, // Changed
          maxMessageSize: 32768, // Changed
          serverId: 'server-2', // Changed
          clientId: 'client-updated', // Changed
        ),
      );

      // Wait for update to be processed
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Connection details were updated
      expect(client.connection.id, equals('connection-id-2'));
      expect(client.connection.key, equals('connection-key-2'));

      // State remains CONNECTED
      expect(client.connection.state, equals(ConnectionState.connected));

      await client.close();
    });

    test(
        'no duplicate CONNECTED events when receiving CONNECTED while connected',
        () async {
      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(
              connectionId: 'connection-id-1',
              connectionKey: 'connection-key-1',
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

      // Track all events
      final allEvents = <Map<String, dynamic>>[];

      // Subscribe to all connection state events
      for (final state in ConnectionState.values) {
        client.connection
            .on(ConnectionEventExtension.fromState(state))
            .listen((change) {
          allEvents.add({
            'type': 'state',
            'state': state,
            'change': change,
          });
        });
      }

      // Also subscribe to UPDATE
      client.connection.on(ConnectionEvent.update).listen((change) {
        allEvents.add({
          'type': 'update',
          'change': change,
        });
      });

      // Start connection
      client.connect();
      await _awaitState(client.connection, ConnectionState.connected);

      // Record event count after initial connection
      final initialEventCount = allEvents.length;

      // Send multiple CONNECTED messages
      for (var i = 1; i <= 3; i++) {
        mockWs.activeConnection!.sendToClient(
          ProtocolMessageHelpers.connected(
            connectionId: 'connection-id-${i + 1}',
            connectionKey: 'connection-key-${i + 1}',
            maxIdleInterval: 15000,
            connectionStateTtl: 120000,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      // Exactly 3 UPDATE events were added
      final newEvents = allEvents.sublist(initialEventCount);
      expect(newEvents.length, equals(3));

      // All new events are UPDATE events, not CONNECTED state events
      for (final event in newEvents) {
        expect(event['type'], equals('update'));
        final change = event['change'] as ConnectionStateChange;
        expect(change.previous, equals(ConnectionState.connected));
        expect(change.current, equals(ConnectionState.connected));
      }

      // No additional CONNECTED state events were emitted
      final connectedStateEvents = allEvents.where((event) =>
          event['type'] == 'state' &&
          event['state'] == ConnectionState.connected);
      expect(connectedStateEvents.length, equals(1)); // Only the initial one

      await client.close();
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
