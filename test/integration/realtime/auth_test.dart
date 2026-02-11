import 'dart:async';
import 'package:test/test.dart';
import 'package:ably_dart/ably_dart.dart';

import '../../helpers/jwt_helper.dart';
import '../../helpers/test_app_helper.dart';

/// Integration tests for Realtime auth.
///
/// These tests run against the Ably Sandbox environment and verify
/// realtime authentication, in-band reauthorization (RTC8), and
/// clientId validation.
///
/// Spec: uts/test/realtime/integration/auth.md
void main() {
  late TestApp testApp;
  late String apiKey;

  setUpAll(() async {
    testApp = await TestApp.provision();
    apiKey = testApp.keys[0].keyStr;
    print('Provisioned test app: ${testApp.appId}');
  });

  tearDownAll(() async {
    await testApp.delete();
    print('Deleted test app: ${testApp.appId}');
  });

  group('RTC8a - In-band reauthorization on CONNECTED client', () {
    test(
        'authorize() on connected client sends AUTH and gets UPDATE, not disconnect',
        () async {
      final client = Realtime(
        options: ClientOptions(
          authCallback: (params) async {
            return JwtHelper.generateToken(
              apiKey: apiKey,
              ttl: 3600000,
            );
          },
          environment: 'sandbox',
          autoConnect: false,
        ),
      );

      // Connect and wait for CONNECTED
      client.connect();
      await _awaitState(client.connection, ConnectionState.connected,
          timeout: const Duration(seconds: 10));

      // Record connection ID before reauth
      final connectionIdBefore = client.connection.id;

      // Collect state changes during reauth
      final stateChanges = <ConnectionStateChange>[];
      final subscription = client.connection.on().listen(stateChanges.add);

      // Call authorize — should send AUTH and get UPDATE, not disconnect
      final token = await client.auth.authorize();

      // Small delay to ensure any state changes have been delivered
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // authorize() returned a valid token
      expect(token, isNotNull);
      expect(token.token, isA<String>());

      // Connection remained connected — same connection ID
      expect(client.connection.id, equals(connectionIdBefore));
      expect(client.connection.state, equals(ConnectionState.connected));

      // No state transitions occurred (UPDATE has current == previous == connected)
      final stateTransitions =
          stateChanges.where((c) => c.current != c.previous).toList();
      expect(stateTransitions, isEmpty,
          reason:
              'Should not have any state transitions during in-band reauth');

      await subscription.cancel();
      await client.close();
    });
  });

  group('RTC8c - authorize() from INITIALIZED initiates connection', () {
    test('authorize() on unconnected client triggers connection', () async {
      final client = Realtime(
        options: ClientOptions(
          authCallback: (params) async {
            return JwtHelper.generateToken(
              apiKey: apiKey,
              ttl: 3600000,
            );
          },
          environment: 'sandbox',
          autoConnect: false,
        ),
      );

      // Client starts in INITIALIZED
      expect(client.connection.state, equals(ConnectionState.initialized));

      // authorize() should trigger connection
      final token = await client.auth.authorize();

      // Wait for connection to be established
      await _awaitState(client.connection, ConnectionState.connected,
          timeout: const Duration(seconds: 10));

      expect(token, isNotNull);
      expect(client.connection.state, equals(ConnectionState.connected));
      expect(client.connection.id, isNotNull);

      await client.close();
    });
  });

  group('RSA8 - Token auth on realtime connection', () {
    test('realtime client connects using JWT-based authCallback', () async {
      final client = Realtime(
        options: ClientOptions(
          authCallback: (params) async {
            return JwtHelper.generateToken(
              apiKey: apiKey,
              ttl: 3600000,
            );
          },
          environment: 'sandbox',
          autoConnect: false,
        ),
      );

      client.connect();
      await _awaitState(client.connection, ConnectionState.connected,
          timeout: const Duration(seconds: 10));

      expect(client.connection.state, equals(ConnectionState.connected));
      expect(client.connection.id, isNotNull);
      expect(client.connection.errorReason, isNull);

      await client.close();
    });
  });

  group('RSA7 - clientId validation on realtime connection', () {
    test('matching clientId in JWT and options succeeds', () async {
      final testClientId =
          'test-client-${DateTime.now().millisecondsSinceEpoch}';

      final client = Realtime(
        options: ClientOptions(
          authCallback: (params) async {
            return JwtHelper.generateToken(
              apiKey: apiKey,
              clientId: testClientId,
              ttl: 3600000,
            );
          },
          clientId: testClientId,
          environment: 'sandbox',
          autoConnect: false,
        ),
      );

      client.connect();
      await _awaitState(client.connection, ConnectionState.connected,
          timeout: const Duration(seconds: 10));

      expect(client.connection.state, equals(ConnectionState.connected));
      expect(client.auth.clientId, equals(testClientId));

      await client.close();
    });

    test('mismatched clientId in token vs options is rejected', () async {
      final client = Realtime(
        options: ClientOptions(
          authCallback: (params) async {
            // Return JWT with clientId "token-client-id"
            return JwtHelper.generateToken(
              apiKey: apiKey,
              clientId: 'token-client-id',
              ttl: 3600000,
            );
          },
          // Options clientId doesn't match JWT clientId
          clientId: 'wrong-client-id',
          environment: 'sandbox',
          autoConnect: false,
        ),
      );

      client.connect();

      // Connection should fail due to clientId mismatch
      await _awaitState(client.connection, ConnectionState.failed,
          timeout: const Duration(seconds: 10));

      expect(client.connection.state, equals(ConnectionState.failed));
      expect(client.connection.errorReason, isNotNull);

      await client.close();
    });
  });
}

/// Waits for connection to reach the specified state.
Future<void> _awaitState(
  Connection connection,
  ConnectionState targetState, {
  required Duration timeout,
}) async {
  if (connection.state == targetState) {
    return;
  }

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
