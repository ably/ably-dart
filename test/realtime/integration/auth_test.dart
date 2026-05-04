@Tags(['integration'])
library;

import 'package:ably_dart/ably_dart.dart';
import 'package:test/test.dart';

import '../../helpers/jwt_helper.dart';
import '../../helpers/test_app_helper.dart';

void main() {
  late TestApp testApp;

  setUpAll(() async {
    testApp = await TestApp.provision();
  });

  tearDownAll(() async {
    await testApp.delete();
  });

  group('Realtime Auth Integration Tests', () {
    // -------------------------------------------------------------------------
    // RTC8a - In-band reauthorization on CONNECTED client
    // -------------------------------------------------------------------------
    test('RTC8a - In-band reauthorization on CONNECTED client', () async {
      final apiKey = testApp.keys[0].keyStr;

      final client = Realtime(
        options: ClientOptions(
          authCallback: (params) async {
            return JwtHelper.generateToken(apiKey: apiKey);
          },
          endpoint: 'sandbox',
          useBinaryProtocol: false,
          autoConnect: false,
        ),
      );
      addTearDown(() async => await client.close());

      // Connect and await CONNECTED state
      await client.connect();
      await client.connection
          .on(ConnectionEvent.connected)
          .first
          .timeout(const Duration(seconds: 10));

      expect(client.connection.state, equals(ConnectionState.connected));

      // Record the connection ID
      final connectionId = client.connection.id;
      expect(connectionId, isNotNull);

      // Collect state changes during reauthorization
      final stateChanges = <ConnectionStateChange>[];
      final subscription = client.connection.on().listen(stateChanges.add);

      // Perform in-band reauthorization
      final token = await client.auth.authorize();

      // Allow a brief period for any state changes to propagate
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await subscription.cancel();

      // Assert: token returned is non-null
      expect(token, isNotNull);

      // Assert: connection ID unchanged (no disconnect)
      expect(client.connection.id, equals(connectionId));

      // Assert: no state transitions where current != previous
      // (i.e., the connection stayed connected throughout)
      final disruptiveChanges = stateChanges
          .where((sc) => sc.current != sc.previous)
          .toList();
      expect(
        disruptiveChanges,
        isEmpty,
        reason: 'Expected no disruptive state transitions during '
            'reauthorization, but got: $disruptiveChanges',
      );
    });

    // -------------------------------------------------------------------------
    // RTC8c - authorize() from INITIALIZED initiates connection
    // -------------------------------------------------------------------------
    test('RTC8c - authorize() from INITIALIZED initiates connection', () async {
      final apiKey = testApp.keys[0].keyStr;

      final client = Realtime(
        options: ClientOptions(
          authCallback: (params) async {
            return JwtHelper.generateToken(apiKey: apiKey);
          },
          endpoint: 'sandbox',
          useBinaryProtocol: false,
          autoConnect: false,
        ),
      );
      addTearDown(() async => await client.close());

      // Assert: starts in INITIALIZED
      expect(client.connection.state, equals(ConnectionState.initialized));

      // Call authorize() which should initiate a connection
      final token = await client.auth.authorize();

      // Await CONNECTED state
      if (client.connection.state != ConnectionState.connected) {
        await client.connection
            .on(ConnectionEvent.connected)
            .first
            .timeout(const Duration(seconds: 10));
      }

      // Assert: token non-null
      expect(token, isNotNull);

      // Assert: state == connected
      expect(client.connection.state, equals(ConnectionState.connected));

      // Assert: connection.id non-null
      expect(client.connection.id, isNotNull);
    });

    // -------------------------------------------------------------------------
    // RSA8 - Token auth via authCallback on realtime
    // -------------------------------------------------------------------------
    test('RSA8 - Token auth via authCallback on realtime', () async {
      final apiKey = testApp.keys[0].keyStr;

      final client = Realtime(
        options: ClientOptions(
          authCallback: (params) async {
            return JwtHelper.generateToken(apiKey: apiKey);
          },
          endpoint: 'sandbox',
          useBinaryProtocol: false,
          autoConnect: false,
        ),
      );
      addTearDown(() async => await client.close());

      // Connect and await CONNECTED
      await client.connect();
      await client.connection
          .on(ConnectionEvent.connected)
          .first
          .timeout(const Duration(seconds: 10));

      // Assert: connected
      expect(client.connection.state, equals(ConnectionState.connected));

      // Assert: connection.id non-null
      expect(client.connection.id, isNotNull);

      // Assert: errorReason null
      expect(client.connection.errorReason, isNull);
    });

    // -------------------------------------------------------------------------
    // RSA7 - matching clientId succeeds
    // -------------------------------------------------------------------------
    test('RSA7 - matching clientId succeeds', () async {
      final apiKey = testApp.keys[0].keyStr;
      final testClientId = 'test-client-${DateTime.now().millisecondsSinceEpoch}';

      final client = Realtime(
        options: ClientOptions(
          authCallback: (params) async {
            return JwtHelper.generateToken(
              apiKey: apiKey,
              clientId: testClientId,
            );
          },
          clientId: testClientId,
          endpoint: 'sandbox',
          useBinaryProtocol: false,
          autoConnect: false,
        ),
      );
      addTearDown(() async => await client.close());

      // Connect and await CONNECTED
      await client.connect();
      await client.connection
          .on(ConnectionEvent.connected)
          .first
          .timeout(const Duration(seconds: 10));

      // Assert: connected
      expect(client.connection.state, equals(ConnectionState.connected));

      // Assert: auth.clientId matches
      expect(client.auth.clientId, equals(testClientId));
    });
  });
}
