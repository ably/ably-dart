@Tags(['integration', 'proxy'])
library;

import 'dart:async';

import 'package:ably_dart/ably_dart.dart';
import 'package:test/test.dart';

import '../../../helpers/jwt_helper.dart';
import '../../../helpers/poll_until.dart';
import '../../../helpers/proxy_helper.dart';
import '../../../helpers/test_app_helper.dart';

Future<Object> Function(TokenParams params) makeAuthCallback(String apiKey) {
  return (params) async => JwtHelper.generateToken(apiKey: apiKey);
}

void main() {
  late TestApp testApp;

  setUpAll(() async {
    await ensureProxy();
    testApp = await TestApp.provision();
  });

  tearDownAll(() async {
    await testApp.delete();
    stopProxy();
  });

  group('Connection Resume Proxy Integration Tests', () {
    // -------------------------------------------------------------------------
    // RTN15a - Unexpected disconnect triggers resume
    // -------------------------------------------------------------------------
    // UTS: realtime/proxy/RTN15a/disconnect-triggers-resume-0
    test('RTN15a - Unexpected disconnect triggers resume', () async {
      final session = await ProxySession.create(
        rules: [
          {
            'match': {'type': 'ws_connect'},
            'action': {
              'type': 'delay_after_ws_connect',
              'delayMs': 1000,
              'then': {'type': 'close'},
            },
            'times': 1,
          },
        ],
      );
      addTearDown(session.close);

      final apiKey = testApp.keys[0].keyStr;
      final stateChanges = <ConnectionStateChange>[];

      final client = Realtime(
        options: ClientOptions(
          authCallback: makeAuthCallback(apiKey),
          endpoint: 'localhost',
          port: session.proxyPort,
          tls: false,
          useBinaryProtocol: false,
          autoConnect: false,
        ),
      );
      addTearDown(client.close);

      client.connection.on().listen(stateChanges.add);

      await client.connect();

      // Wait for initial CONNECTED
      await client.connection
          .on(ConnectionEvent.connected)
          .first
          .timeout(const Duration(seconds: 10));

      // Wait for DISCONNECTED (proxy closes after 1s)
      await client.connection
          .on(ConnectionEvent.disconnected)
          .first
          .timeout(const Duration(seconds: 5));

      // Wait for reconnect CONNECTED
      await client.connection
          .on(ConnectionEvent.connected)
          .first
          .timeout(const Duration(seconds: 15));

      // Assert state changes contain disconnected -> connecting -> connected
      final states = stateChanges.map((e) => e.current).toList();
      final disconnectedIdx = states.indexOf(ConnectionState.disconnected);
      expect(
        disconnectedIdx,
        greaterThanOrEqualTo(0),
        reason: 'Should have entered DISCONNECTED',
      );
      final subsequentStates = states.sublist(disconnectedIdx + 1);
      expect(subsequentStates, contains(ConnectionState.connecting));
      expect(subsequentStates, contains(ConnectionState.connected));

      // Verify proxy log shows >= 2 ws_connect events and second has resume
      final log = await session.getLog();
      final wsConnects = log.where((e) => e['type'] == 'ws_connect').toList();
      expect(
        wsConnects.length,
        greaterThanOrEqualTo(2),
        reason: 'Should have at least 2 WebSocket connections',
      );

      final secondUrl = wsConnects[1]['url'] as String? ?? '';
      expect(
        secondUrl,
        contains('resume='),
        reason: 'Second connection should include resume parameter',
      );
    });

    // -------------------------------------------------------------------------
    // RTN15b, RTN15c6 - Resume preserves connectionId
    // -------------------------------------------------------------------------
    // UTS: realtime/proxy/RTN15b/resume-preserves-connid-0
    test('RTN15b, RTN15c6 - Resume preserves connectionId', () async {
      final session = await ProxySession.create(
        rules: [
          {
            'match': {'type': 'ws_connect'},
            'action': {
              'type': 'delay_after_ws_connect',
              'delayMs': 1000,
              'then': {'type': 'close'},
            },
            'times': 1,
          },
        ],
      );
      addTearDown(session.close);

      final apiKey = testApp.keys[0].keyStr;

      final client = Realtime(
        options: ClientOptions(
          authCallback: makeAuthCallback(apiKey),
          endpoint: 'localhost',
          port: session.proxyPort,
          tls: false,
          useBinaryProtocol: false,
          autoConnect: false,
        ),
      );
      addTearDown(client.close);

      await client.connect();
      await client.connection
          .on(ConnectionEvent.connected)
          .first
          .timeout(const Duration(seconds: 10));

      final originalId = client.connection.id;
      final originalKey = client.connection.key;
      expect(originalId, isNotNull);
      expect(originalKey, isNotNull);

      // Wait for disconnect then reconnect
      await client.connection
          .on(ConnectionEvent.disconnected)
          .first
          .timeout(const Duration(seconds: 5));
      await client.connection
          .on(ConnectionEvent.connected)
          .first
          .timeout(const Duration(seconds: 15));

      // Assert: connectionId is preserved after resume
      expect(client.connection.id, equals(originalId),
          reason: 'connectionId should be preserved after successful resume',);

      // Verify proxy log shows resume with original key
      final log = await session.getLog();
      final wsConnects = log.where((e) => e['type'] == 'ws_connect').toList();
      expect(wsConnects.length, greaterThanOrEqualTo(2));

      final secondUrl = wsConnects[1]['url'] as String? ?? '';
      expect(secondUrl, contains('resume='),
          reason: 'Second connection should include resume parameter',);
    });

    // -------------------------------------------------------------------------
    // RTN15c7 - Failed resume gets new connectionId
    // -------------------------------------------------------------------------
    // UTS: realtime/proxy/RTN15c7/failed-resume-new-connid-0
    test('RTN15c7 - Failed resume gets new connectionId', () async {
      final session = await ProxySession.create(
        rules: [
          // Rule 1: Close after 1s on first connection
          {
            'match': {'type': 'ws_connect'},
            'action': {
              'type': 'delay_after_ws_connect',
              'delayMs': 1000,
              'then': {'type': 'close'},
            },
            'times': 1,
          },
          // Rule 2: On second connection, replace CONNECTED with new id/key
          // and error 80008 to indicate resume failed
          {
            'match': {
              'type': 'ws_frame_to_client',
              'action': 4, // CONNECTED
            },
            'action': {
              'type': 'replace',
              'message': {
                'action': 4, // CONNECTED
                'connectionId': 'proxy-injected-new-id',
                'connectionDetails': {
                  'connectionKey': 'proxy-injected-new-key',
                  'connectionStateTtl': 120000,
                  'maxIdleInterval': 15000,
                  'maxFrameSize': 524288,
                  'maxInboundRate': 250,
                  'maxMessageSize': 65536,
                  'serverId': 'proxy-server',
                  'clientId': null,
                },
                'error': {
                  'message': 'Connection resume failed',
                  'code': 80008,
                  'statusCode': 401,
                },
              },
            },
            'times': 1,
          },
        ],
      );
      addTearDown(session.close);

      final apiKey = testApp.keys[0].keyStr;

      final client = Realtime(
        options: ClientOptions(
          authCallback: makeAuthCallback(apiKey),
          endpoint: 'localhost',
          port: session.proxyPort,
          tls: false,
          useBinaryProtocol: false,
          autoConnect: false,
        ),
      );
      addTearDown(client.close);

      await client.connect();
      await client.connection
          .on(ConnectionEvent.connected)
          .first
          .timeout(const Duration(seconds: 10));

      final originalId = client.connection.id;
      expect(originalId, isNotNull);

      // Wait for disconnect then reconnect
      await client.connection
          .on(ConnectionEvent.disconnected)
          .first
          .timeout(const Duration(seconds: 5));

      // Wait for UPDATE or CONNECTED event that signals new connection
      await client.connection
          .on(ConnectionEvent.connected)
          .first
          .timeout(const Duration(seconds: 15));

      // Assert: new connectionId from proxy injection
      expect(client.connection.id, equals('proxy-injected-new-id'),
          reason: 'After failed resume, should have proxy-injected new id',);

      // Assert: errorReason.code == 80008
      expect(client.connection.errorReason, isNotNull);
      expect(client.connection.errorReason!.code, equals(80008),
          reason: 'Error code should be 80008 for failed resume',);
    });

    // -------------------------------------------------------------------------
    // RTN15h1 - Non-renewable token with DISCONNECTED 40142 -> FAILED
    // -------------------------------------------------------------------------
    // UTS: realtime/proxy/RTN15h1/token-error-nonrenewable-failed-0
    test('RTN15h1 - Non-renewable token with DISCONNECTED 40142 -> FAILED',
        () async {
      final session = await ProxySession.create(
        rules: [
          {
            'match': {'type': 'ws_connect'},
            'action': {
              'type': 'delay_after_ws_connect',
              'delayMs': 1000,
              'then': {
                'type': 'inject_to_client_and_close',
                'message': {
                  'action': 6, // DISCONNECTED
                  'error': {
                    'message': 'Token expired',
                    'code': 40142,
                    'statusCode': 401,
                  },
                },
              },
            },
            'times': 1,
          },
        ],
      );
      addTearDown(session.close);

      // Get a real token via REST (no key/callback = non-renewable)
      final apiKey = testApp.keys[0].keyStr;
      final restClient = Rest(
        options: ClientOptions(
          key: apiKey,
          endpoint: 'sandbox',
          useBinaryProtocol: false,
        ),
      );
      final tokenDetails = await restClient.auth.requestToken();
      final tokenString = tokenDetails.token!;

      final client = Realtime(
        options: ClientOptions(
          token: tokenString,
          endpoint: 'localhost',
          port: session.proxyPort,
          tls: false,
          useBinaryProtocol: false,
          autoConnect: false,
        ),
      );
      addTearDown(client.close);

      await client.connect();

      // Wait for CONNECTED first
      await client.connection
          .on(ConnectionEvent.connected)
          .first
          .timeout(const Duration(seconds: 10));

      // After 1s the proxy injects DISCONNECTED with 40142, which should
      // cause FAILED since the token is non-renewable
      await client.connection
          .on(ConnectionEvent.failed)
          .first
          .timeout(const Duration(seconds: 10));

      expect(client.connection.state, equals(ConnectionState.failed));
      expect(client.connection.errorReason, isNotNull);
      // The specific code may be 40142 or 40171 depending on SDK handling
      expect(
        client.connection.errorReason!.code,
        anyOf(equals(40142), equals(40171)),
        reason: 'Should fail with token-related error code',
      );
    });

    // -------------------------------------------------------------------------
    // RTN15h3 - Non-token DISCONNECTED error triggers reconnect
    // -------------------------------------------------------------------------
    // UTS: realtime/proxy/RTN15h3/non-token-error-reconnects-0
    test('RTN15h3 - Non-token DISCONNECTED error triggers reconnect', () async {
      final session = await ProxySession.create(
        rules: [
          {
            'match': {'type': 'ws_connect'},
            'action': {
              'type': 'delay_after_ws_connect',
              'delayMs': 1000,
              'then': {
                'type': 'inject_to_client_and_close',
                'message': {
                  'action': 6, // DISCONNECTED
                  'error': {
                    'message': 'Internal error',
                    'code': 80003,
                    'statusCode': 500,
                  },
                },
              },
            },
            'times': 1,
          },
        ],
      );
      addTearDown(session.close);

      final apiKey = testApp.keys[0].keyStr;
      final stateChanges = <ConnectionStateChange>[];

      final client = Realtime(
        options: ClientOptions(
          authCallback: makeAuthCallback(apiKey),
          endpoint: 'localhost',
          port: session.proxyPort,
          tls: false,
          useBinaryProtocol: false,
          autoConnect: false,
        ),
      );
      addTearDown(client.close);

      client.connection.on().listen(stateChanges.add);

      await client.connect();

      // Wait for initial CONNECTED
      await client.connection
          .on(ConnectionEvent.connected)
          .first
          .timeout(const Duration(seconds: 10));

      // Wait for DISCONNECTED (proxy injects after 1s)
      await client.connection
          .on(ConnectionEvent.disconnected)
          .first
          .timeout(const Duration(seconds: 5));

      // Wait for successful reconnect
      await client.connection
          .on(ConnectionEvent.connected)
          .first
          .timeout(const Duration(seconds: 15));

      expect(client.connection.state, equals(ConnectionState.connected));

      // Assert: no FAILED state in the history
      final states = stateChanges.map((e) => e.current).toList();
      expect(states, isNot(contains(ConnectionState.failed)),
          reason: 'Non-token error should not cause FAILED state',);
    });

    // -------------------------------------------------------------------------
    // RTN15j - Fatal ERROR on established connection -> FAILED
    // -------------------------------------------------------------------------
    // UTS: realtime/proxy/RTN15j/fatal-error-established-conn-0
    test('RTN15j - Fatal ERROR on established connection -> FAILED', () async {
      // No proxy rules - passthrough
      final session = await ProxySession.create();
      addTearDown(session.close);

      final apiKey = testApp.keys[0].keyStr;

      final client = Realtime(
        options: ClientOptions(
          authCallback: makeAuthCallback(apiKey),
          endpoint: 'localhost',
          port: session.proxyPort,
          tls: false,
          useBinaryProtocol: false,
          autoConnect: false,
        ),
      );
      addTearDown(client.close);

      await client.connect();
      await client.connection
          .on(ConnectionEvent.connected)
          .first
          .timeout(const Duration(seconds: 10));

      // Attach two channels
      final ch1 = client.channels.get('rtn15j-channel1');
      final ch2 = client.channels.get('rtn15j-channel2');
      await ch1.attach();
      await ch2.attach();

      // Inject fatal ERROR via triggerAction
      await session.triggerAction({
        'type': 'inject_to_client',
        'message': {
          'action': 9, // ERROR
          'error': {
            'message': 'Fatal server error',
            'code': 50000,
            'statusCode': 500,
          },
        },
      });

      // Wait for FAILED
      await client.connection
          .on(ConnectionEvent.failed)
          .first
          .timeout(const Duration(seconds: 10));

      expect(client.connection.state, equals(ConnectionState.failed));
      expect(client.connection.errorReason, isNotNull);
      expect(client.connection.errorReason!.code, equals(50000));

      // Both channels should be FAILED
      expect(ch1.state, equals(ChannelState.failed));
      expect(ch2.state, equals(ChannelState.failed));
    });

    // -------------------------------------------------------------------------
    // RTN15g, RTN15g2 - connectionStateTtl expiry prevents resume
    // -------------------------------------------------------------------------
    // UTS: realtime/proxy/RTN15g/ttl-expiry-clears-resume-0
    test('RTN15g, RTN15g2 - connectionStateTtl expiry prevents resume',
        () async {
      final session = await ProxySession.create(
        rules: [
          // Rule 1: Replace first CONNECTED with connectionStateTtl=2000
          {
            'match': {
              'type': 'ws_frame_to_client',
              'action': 4, // CONNECTED
            },
            'action': {
              'type': 'modify',
              'set': {
                'connectionDetails.connectionStateTtl': 2000,
              },
            },
            'times': 1,
          },
          // Rule 2: Close after 1s on first established connection
          {
            'match': {'type': 'ws_connect'},
            'action': {
              'type': 'delay_after_ws_connect',
              'delayMs': 1000,
              'then': {'type': 'close'},
            },
            'times': 1,
          },
          // Rule 3: Refuse second ws_connect to force retry delay
          {
            'match': {'type': 'ws_connect'},
            'action': {'type': 'refuse'},
            'times': 1,
          },
        ],
      );
      addTearDown(session.close);

      final apiKey = testApp.keys[0].keyStr;
      final stateChanges = <ConnectionStateChange>[];

      final client = Realtime(
        options: ClientOptions(
          authCallback: makeAuthCallback(apiKey),
          endpoint: 'localhost',
          port: session.proxyPort,
          tls: false,
          useBinaryProtocol: false,
          autoConnect: false,
          suspendedRetryTimeout: 1000,
        ),
      );
      addTearDown(client.close);

      client.connection.on().listen(stateChanges.add);

      await client.connect();
      await client.connection
          .on(ConnectionEvent.connected)
          .first
          .timeout(const Duration(seconds: 10));

      final originalId = client.connection.id;
      expect(originalId, isNotNull);

      // Wait for SUSPENDED (after TTL expiry ~3s: 1s connect + 2s TTL)
      await client.connection
          .on(ConnectionEvent.suspended)
          .first
          .timeout(const Duration(seconds: 15));

      // Wait for eventual reconnect with fresh connection (no resume)
      await client.connection
          .on(ConnectionEvent.connected)
          .first
          .timeout(const Duration(seconds: 15));

      // Assert: new connectionId (fresh connect, not resumed)
      expect(client.connection.id, isNot(equals(originalId)),
          reason: 'After TTL expiry, should get a new connectionId',);

      // Verify proxy log: last ws_connect has no resume param
      final log = await session.getLog();
      final wsConnects = log.where((e) => e['type'] == 'ws_connect').toList();
      final lastUrl = wsConnects.last['url'] as String? ?? '';
      expect(lastUrl, isNot(contains('resume=')),
          reason: 'Fresh connect after TTL expiry should not include resume',);
    });

    // -------------------------------------------------------------------------
    // RTN19a, RTN19a2 - Unacked messages resent after resume
    // -------------------------------------------------------------------------
    // UTS: realtime/proxy/RTN19a/unacked-resent-on-resume-0
    test('RTN19a, RTN19a2 - Unacked messages resent after resume', () async {
      final session = await ProxySession.create(
        rules: [
          // Suppress the first ACK from server to client
          {
            'match': {
              'type': 'ws_frame_to_client',
              'action': 1, // ACK
            },
            'action': {'type': 'drop'},
            'times': 1,
          },
        ],
      );
      addTearDown(session.close);

      final apiKey = testApp.keys[0].keyStr;
      final channelName = 'rtn19a-${DateTime.now().millisecondsSinceEpoch}';

      final client = Realtime(
        options: ClientOptions(
          authCallback: makeAuthCallback(apiKey),
          endpoint: 'localhost',
          port: session.proxyPort,
          tls: false,
          useBinaryProtocol: false,
          autoConnect: false,
        ),
      );
      addTearDown(client.close);

      await client.connect();
      await client.connection
          .on(ConnectionEvent.connected)
          .first
          .timeout(const Duration(seconds: 10));

      final channel = client.channels.get(channelName);
      await channel.attach();

      // Start publish (don't await yet) - the ACK will be suppressed
      final publishFuture = channel.publish(name: 'test', data: 'hello');

      // Poll proxy log until we see the MESSAGE sent and ACK suppressed
      await pollUntil(() async {
        final log = await session.getLog();
        final hasMessage = log.any((e) =>
            e['type'] == 'ws_frame_to_server' && e['action'] == 15,); // MESSAGE
        final hasDroppedAck = log.any((e) =>
            e['type'] == 'ws_frame_to_client' &&
            e['action'] == 1 && // ACK
            e['dropped'] == true,);
        if (hasMessage && hasDroppedAck) return true;
        return null;
      },);

      // Force disconnect via triggerAction
      await session.triggerAction({'type': 'close'});

      // Wait for reconnect
      await client.connection
          .on(ConnectionEvent.disconnected)
          .first
          .timeout(const Duration(seconds: 5));
      await client.connection
          .on(ConnectionEvent.connected)
          .first
          .timeout(const Duration(seconds: 15));

      // Now the publish should complete after the message is resent
      await publishFuture.timeout(const Duration(seconds: 10));

      // Verify proxy log has >= 2 MESSAGE frames
      final log = await session.getLog();
      final messageFrames = log
          .where((e) =>
              e['type'] == 'ws_frame_to_server' && e['action'] == 15,) // MESSAGE
          .toList();
      expect(messageFrames.length, greaterThanOrEqualTo(2),
          reason: 'Message should be resent after resume',);
    });
  });
}
