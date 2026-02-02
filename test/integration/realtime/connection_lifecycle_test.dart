import 'dart:async';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:ably_dart/ably_dart.dart';

/// Integration tests for Realtime connection lifecycle.
///
/// These tests run against the Ably Sandbox environment and verify
/// the basic connection flow: connect, disconnect, reconnect.
///
/// Spec: uts/test/realtime/integration/connection_lifecycle_test.md
void main() {
  late String apiKey;
  late String appId;

  setUpAll(() async {
    // Provision test app in Sandbox
    final response = await http.post(
      Uri.parse('https://sandbox-rest.ably.io/apps'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'keys': [
          {'capability': '{"*":["*"]}'}
        ],
        'namespaces': [
          {'id': 'persisted', 'persisted': true}
        ],
        'channels': [
          {
            'name': 'persisted:test',
            'presence': [
              {'clientId': 'test-client', 'data': 'test-data'}
            ]
          }
        ]
      }),
    );

    expect(response.statusCode, equals(201));
    final appConfig = jsonDecode(response.body) as Map<String, dynamic>;
    final keys = appConfig['keys'] as List;
    apiKey = keys[0]['keyStr'] as String;
    appId = appConfig['appId'] as String;

    print('Provisioned test app: $appId');
  });

  tearDownAll(() async {
    if (appId.isNotEmpty && apiKey.isNotEmpty) {
      // Clean up test app
      final authBytes = utf8.encode(apiKey);
      final authHeader = 'Basic ${base64Encode(authBytes)}';

      await http.delete(
        Uri.parse('https://sandbox-rest.ably.io/apps/$appId'),
        headers: {'Authorization': authHeader},
      );

      print('Deleted test app: $appId');
    }
  });

  group('RTN4b, RTN21 - Successful connection establishment', () {
    test('connects via WebSocket and reaches CONNECTED state', () async {
      final client = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
        ),
      );

      // Client starts in INITIALIZED state
      expect(client.connection.state, equals(ConnectionState.initialized));

      // Start connection
      client.connect();

      // Wait for CONNECTING state
      await _awaitState(client.connection, ConnectionState.connecting,
          timeout: Duration(seconds: 5));

      // Wait for CONNECTED state
      await _awaitState(client.connection, ConnectionState.connected,
          timeout: Duration(seconds: 10));

      // Verify connection properties are set
      expect(client.connection.id, isNotNull);
      expect(client.connection.id, isNotEmpty);
      expect(client.connection.key, isNotNull);
      expect(client.connection.key, isNotEmpty);

      // Verify final state
      expect(client.connection.state, equals(ConnectionState.connected));
      expect(client.connection.errorReason, isNull);

      // Connection ID should match pattern
      expect(client.connection.id, matches(RegExp(r'^[a-zA-Z0-9_-]+$')));

      // Connection key should match pattern
      expect(client.connection.key, matches(RegExp(r'^[a-zA-Z0-9_!-]+$')));

      await client.close();
    });
  });

  group('RTN4c, RTN12, RTN12a - Graceful connection close', () {
    test('closes connection gracefully from CONNECTED state', () async {
      final client = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
        ),
      );

      // Establish connection first
      client.connect();
      await _awaitState(client.connection, ConnectionState.connected,
          timeout: Duration(seconds: 10));

      // Close the connection
      client.connection.close();

      // Should transition through CLOSING
      await _awaitState(client.connection, ConnectionState.closing,
          timeout: Duration(seconds: 2));

      // Should reach CLOSED
      await _awaitState(client.connection, ConnectionState.closed,
          timeout: Duration(seconds: 5));

      // Verify final state
      expect(client.connection.state, equals(ConnectionState.closed));
      expect(client.connection.errorReason, isNull);

      // Connection ID and key should be cleared
      expect(client.connection.id, isNull);
      expect(client.connection.key, isNull);
    });
  });

  group('RTN11, RTN4b - Connect and reconnect cycle', () {
    test('can be closed and reconnected multiple times', () async {
      final client = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          autoConnect: false,
        ),
      );

      // Initial state
      expect(client.connection.state, equals(ConnectionState.initialized));

      // First connection
      client.connect();
      await _awaitState(client.connection, ConnectionState.connected,
          timeout: Duration(seconds: 10));

      final firstConnectionId = client.connection.id;
      expect(firstConnectionId, isNotNull);

      // Close connection
      client.connection.close();
      await _awaitState(client.connection, ConnectionState.closed,
          timeout: Duration(seconds: 5));

      // Reconnect
      client.connect();
      await _awaitState(client.connection, ConnectionState.connected,
          timeout: Duration(seconds: 10));

      final secondConnectionId = client.connection.id;
      expect(secondConnectionId, isNotNull);

      // Each connection gets a new ID (not a resume since we closed)
      expect(secondConnectionId, isNot(equals(firstConnectionId)));

      // No errors
      expect(client.connection.errorReason, isNull);

      await client.close();
    });
  });

  group('RTN11e - Connect when already connecting/connected', () {
    test('calling connect() when already connecting is a no-op', () async {
      final client = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          autoConnect: false,
        ),
      );

      // Start connecting
      client.connect();
      await _awaitState(client.connection, ConnectionState.connecting,
          timeout: Duration(seconds: 5));

      // Call connect() again while CONNECTING - should be no-op
      client.connect();

      // Should still reach CONNECTED normally
      await _awaitState(client.connection, ConnectionState.connected,
          timeout: Duration(seconds: 10));

      final connectionId = client.connection.id;

      // Call connect() again while CONNECTED - should be no-op
      client.connect();

      // Wait briefly to ensure state doesn't change
      await Future.delayed(Duration(seconds: 1));

      // Should remain CONNECTED with same connection
      expect(client.connection.state, equals(ConnectionState.connected));
      expect(client.connection.id, equals(connectionId));

      await client.close();
    });
  });
}

/// Waits for connection to reach the specified state.
///
/// Throws [TimeoutException] if timeout is exceeded.
Future<void> _awaitState(
  Connection connection,
  ConnectionState targetState, {
  required Duration timeout,
}) async {
  // If already in target state, return immediately
  if (connection.state == targetState) {
    return;
  }

  // Wait for state change event
  final completer = Completer<void>();
  late StreamSubscription<ConnectionStateChange> subscription;

  subscription = connection.on().listen((stateChange) {
    if (stateChange.current == targetState) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  });

  try {
    await completer.future.timeout(timeout);
  } finally {
    await subscription.cancel();
  }
}
