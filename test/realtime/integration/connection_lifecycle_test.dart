@Tags(['integration'])
library;

import 'package:ably_dart/ably_dart.dart';
import 'package:test/test.dart';

import '../../helpers/test_app_helper.dart';

void main() {
  late TestApp testApp;

  setUpAll(() async {
    testApp = await TestApp.provision();
  });

  tearDownAll(() async {
    await testApp.delete();
  });

  group('Realtime Connection Lifecycle Integration Tests', () {
    // -------------------------------------------------------------------------
    // RTN4b, RTN21 - Successful connection establishment
    // -------------------------------------------------------------------------
    // UTS: realtime/integration/RTN4b/successful-connection-0
    test('RTN4b, RTN21 - Successful connection establishment', () async {
      final client = Realtime(
        options: ClientOptions(
          key: testApp.keys[0].keyStr,
          endpoint: 'nonprod:sandbox',
          useBinaryProtocol: false,
          autoConnect: false,
        ),
      );
      addTearDown(() async => await client.close());

      // Assert: starts in INITIALIZED
      expect(client.connection.state, equals(ConnectionState.initialized));

      // Connect
      await client.connect();

      // Await CONNECTED with 10s timeout
      await client.connection
          .on(ConnectionEvent.connected)
          .first
          .timeout(const Duration(seconds: 10));

      // Assert: state == connected
      expect(client.connection.state, equals(ConnectionState.connected));

      // Assert: connection.id is non-empty string
      expect(client.connection.id, isNotNull);
      expect(client.connection.id, isNotEmpty);

      // Assert: connection.key is non-empty string
      expect(client.connection.key, isNotNull);
      expect(client.connection.key, isNotEmpty);

      // Assert: errorReason is null
      expect(client.connection.errorReason, isNull);
    });

    // -------------------------------------------------------------------------
    // RTN4c, RTN12, RTN12a - Graceful connection close
    // -------------------------------------------------------------------------
    // UTS: realtime/integration/RTN4c/graceful-close-0
    test('RTN4c, RTN12, RTN12a - Graceful connection close', () async {
      final client = Realtime(
        options: ClientOptions(
          key: testApp.keys[0].keyStr,
          endpoint: 'nonprod:sandbox',
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
      expect(client.connection.state, equals(ConnectionState.connected));

      // Close the connection
      await client.close();

      // Await CLOSED state (5s timeout)
      if (client.connection.state != ConnectionState.closed) {
        await client.connection
            .on(ConnectionEvent.closed)
            .first
            .timeout(const Duration(seconds: 5));
      }

      // Assert: state == closed
      expect(client.connection.state, equals(ConnectionState.closed));

      // Assert: errorReason null
      expect(client.connection.errorReason, isNull);
    });

    // -------------------------------------------------------------------------
    // RTN11, RTN4b - Connect and reconnect cycle
    // -------------------------------------------------------------------------
    // UTS: realtime/integration/RTN11/connect-reconnect-cycle-0
    test('RTN11, RTN4b - Connect and reconnect cycle', () async {
      final client = Realtime(
        options: ClientOptions(
          key: testApp.keys[0].keyStr,
          endpoint: 'nonprod:sandbox',
          useBinaryProtocol: false,
          autoConnect: false,
        ),
      );
      addTearDown(() async => await client.close());

      // First connection
      await client.connect();
      await client.connection
          .on(ConnectionEvent.connected)
          .first
          .timeout(const Duration(seconds: 10));
      expect(client.connection.state, equals(ConnectionState.connected));

      final firstConnectionId = client.connection.id;
      expect(firstConnectionId, isNotNull);

      // Close the connection
      await client.close();
      if (client.connection.state != ConnectionState.closed) {
        await client.connection
            .on(ConnectionEvent.closed)
            .first
            .timeout(const Duration(seconds: 5));
      }
      expect(client.connection.state, equals(ConnectionState.closed));

      // Reconnect
      await client.connect();
      await client.connection
          .on(ConnectionEvent.connected)
          .first
          .timeout(const Duration(seconds: 10));
      expect(client.connection.state, equals(ConnectionState.connected));

      final secondConnectionId = client.connection.id;
      expect(secondConnectionId, isNotNull);

      // Assert: both IDs non-null, IDs are different (not resumed)
      expect(firstConnectionId, isNotNull);
      expect(secondConnectionId, isNotNull);
      expect(
        secondConnectionId,
        isNot(equals(firstConnectionId)),
        reason: 'After close + reconnect, connection ID should be different '
            '(not a resumed connection)',
      );
    });
  });
}
