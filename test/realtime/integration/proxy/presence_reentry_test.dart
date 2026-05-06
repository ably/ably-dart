@Tags(['integration', 'proxy'])
library;

import 'package:ably_dart/ably_dart.dart';
import 'package:test/test.dart';

import '../../../helpers/jwt_helper.dart';
import '../../../helpers/poll_until.dart';
import '../../../helpers/proxy_helper.dart';
import '../../../helpers/test_app_helper.dart';

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

  group('Presence Re-entry Proxy Integration Tests', () {
    // -------------------------------------------------------------------------
    // RTP17i/RTP17g - Automatic presence re-enter on non-resumed ATTACHED
    //                 (injection)
    // -------------------------------------------------------------------------
    test(
      'RTP17i/RTP17g - Automatic presence re-enter on non-resumed '
      'ATTACHED (injection)',
      () async {
        final apiKey = testApp.keys[0].keyStr;
        const clientId = 'client-a';
        final channelName =
            'rtp17i-reenter-${DateTime.now().millisecondsSinceEpoch}';

        // No rules (passthrough)
        final session = await ProxySession.create();
        addTearDown(() async => await session.close());

        final client = Realtime(
          options: ClientOptions(
            authCallback: (params) async {
              return JwtHelper.generateToken(
                apiKey: apiKey,
                clientId: clientId,
              );
            },
            clientId: clientId,
            endpoint: 'localhost',
            port: session.proxyPort,
            tls: false,
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

        final channel = client.channels.get(channelName);

        // Attach and enter presence
        await channel.attach();
        await pollUntil(
          () async {
            if (channel.state == ChannelState.attached) return true;
            return null;
          },
        );
        await channel.presence.enter('hello');

        // Allow presence to settle
        await Future<void>.delayed(const Duration(seconds: 1));

        // Record baseline PRESENCE frame count from proxy log
        final baselineLog = await session.getLog();
        final baselinePresenceCount = baselineLog.where((event) {
          final type = event['type'] as String? ?? '';
          if (type != 'ws_frame_to_server') return false;
          final message = event['message'] as Map<String, dynamic>? ?? {};
          return message['action'] == 14; // PRESENCE
        }).length;

        // Inject ATTACHED (action 11) with flags=0 (non-resumed), error 91001
        await session.triggerAction({
          'action': 'inject_to_client',
          'message': {
            'action': 11, // ATTACHED
            'channel': channelName,
            'flags': 0,
            'error': {
              'code': 91001,
              'statusCode': 500,
              'message': 'Channel reattached without resume',
            },
          },
        });

        // Poll until proxy log shows new PRESENCE frame from client
        await pollUntil(
          () async {
            final log = await session.getLog();
            final presenceFrames = log.where((event) {
              final type = event['type'] as String? ?? '';
              if (type != 'ws_frame_to_server') return false;
              final message =
                  event['message'] as Map<String, dynamic>? ?? {};
              return message['action'] == 14; // PRESENCE
            }).toList();
            if (presenceFrames.length > baselinePresenceCount) {
              return presenceFrames;
            }
            return null;
          },
        );

        // Get the re-enter PRESENCE frame
        final finalLog = await session.getLog();
        final presenceFrames = finalLog.where((event) {
          final type = event['type'] as String? ?? '';
          if (type != 'ws_frame_to_server') return false;
          final message = event['message'] as Map<String, dynamic>? ?? {};
          return message['action'] == 14; // PRESENCE
        }).toList();

        // The re-enter frame is the latest presence frame
        expect(
          presenceFrames.length,
          greaterThan(baselinePresenceCount),
          reason: 'Should have a new PRESENCE frame after non-resumed ATTACHED',
        );

        final reenterFrame = presenceFrames.last;
        final reenterMessage =
            reenterFrame['message'] as Map<String, dynamic>? ?? {};
        final presenceList =
            reenterMessage['presence'] as List<dynamic>? ?? [];
        expect(presenceList, isNotEmpty, reason: 'PRESENCE frame should have presence data');

        final presenceEntry = presenceList.first as Map<String, dynamic>;
        expect(
          presenceEntry['clientId'],
          equals(clientId),
          reason: 'Re-enter should have correct clientId',
        );
        expect(
          presenceEntry['data'],
          equals('hello'),
          reason: 'Re-enter should preserve the original data',
        );
        // action 2 = ENTER
        expect(
          presenceEntry['action'],
          equals(2),
          reason: 'Re-enter should use ENTER action (2)',
        );
      },
    );

    // -------------------------------------------------------------------------
    // RTP17i - Presence re-enter after real disconnect
    // -------------------------------------------------------------------------
    // UTS: realtime/proxy/RTP17i/reenter-after-disconnect-1
    test('RTP17i - Presence re-enter after real disconnect', () async {
      final apiKey = testApp.keys[0].keyStr;
      const clientId = 'client-a';
      final channelName =
          'rtp17i-disconnect-${DateTime.now().millisecondsSinceEpoch}';

      // Two proxy rules:
      // 1. Close WebSocket after 3s (times: 1) to cause disconnect
      // 2. Replace 2nd ATTACHED for channel with non-resumed (flags=0)
      final session = await ProxySession.create(
        rules: [
          {
            'match': {
              'type': 'ws_connect',
            },
            'action': 'close',
            'delayMs': 3000,
            'times': 1,
            'skip': 1, // Skip the first connection, close the second
          },
          {
            'match': {
              'type': 'ws_frame_to_client',
              'action': 11, // ATTACHED
              'channel': channelName,
            },
            'action': 'replace',
            'replacement': {
              'action': 11, // ATTACHED
              'channel': channelName,
              'flags': 0,
              'error': {
                'code': 91001,
                'statusCode': 500,
                'message': 'Channel reattached without resume',
              },
            },
            'times': 1,
            'skip': 1, // Skip 1st ATTACHED, replace 2nd
          },
        ],
      );
      addTearDown(() async => await session.close());

      final client = Realtime(
        options: ClientOptions(
          authCallback: (params) async {
            return JwtHelper.generateToken(
              apiKey: apiKey,
              clientId: clientId,
            );
          },
          clientId: clientId,
          endpoint: 'localhost',
          port: session.proxyPort,
          tls: false,
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

      final channel = client.channels.get(channelName);

      // Attach and enter presence
      await channel.attach();
      await pollUntil(
        () async {
          if (channel.state == ChannelState.attached) return true;
          return null;
        },
      );
      await channel.presence.enter('hello');

      // Allow presence to settle
      await Future<void>.delayed(const Duration(seconds: 1));

      // Wait for DISCONNECTED (triggered by close after 3s)
      await pollUntil(
        () async {
          if (client.connection.state == ConnectionState.disconnected) {
            return true;
          }
          return null;
        },
      );

      // Wait for reconnection
      await client.connection
          .on(ConnectionEvent.connected)
          .first
          .timeout(const Duration(seconds: 30));

      // Wait for channel to become ATTACHED
      await pollUntil(
        () async {
          if (channel.state == ChannelState.attached) return true;
          return null;
        },
        timeout: const Duration(seconds: 15),
      );

      // Allow time for presence re-enter
      await Future<void>.delayed(const Duration(seconds: 2));

      // Check proxy log for PRESENCE frame after 2nd ws_connect
      final log = await session.getLog();

      // Find the index of the 2nd ws_connect event
      var wsConnectCount = 0;
      var secondConnectIndex = -1;
      for (var i = 0; i < log.length; i++) {
        if ((log[i]['type'] as String? ?? '') == 'ws_connect') {
          wsConnectCount++;
          if (wsConnectCount == 2) {
            secondConnectIndex = i;
            break;
          }
        }
      }

      // Look for PRESENCE frames after the 2nd connect
      final presenceAfterReconnect = <Map<String, dynamic>>[];
      if (secondConnectIndex >= 0) {
        for (var i = secondConnectIndex; i < log.length; i++) {
          final event = log[i];
          final type = event['type'] as String? ?? '';
          if (type == 'ws_frame_to_server') {
            final message =
                event['message'] as Map<String, dynamic>? ?? {};
            if (message['action'] == 14) {
              // PRESENCE
              presenceAfterReconnect.add(event);
            }
          }
        }
      }

      expect(
        presenceAfterReconnect,
        isNotEmpty,
        reason: 'Should have PRESENCE frame after reconnection',
      );

      // Verify the re-enter frame
      final reenterFrame = presenceAfterReconnect.first;
      final reenterMessage =
          reenterFrame['message'] as Map<String, dynamic>? ?? {};
      final presenceList =
          reenterMessage['presence'] as List<dynamic>? ?? [];
      expect(presenceList, isNotEmpty);

      final presenceEntry = presenceList.first as Map<String, dynamic>;
      expect(presenceEntry['action'], equals(2),
          reason: 'Re-enter action should be ENTER (2)',);
      expect(presenceEntry['clientId'], equals(clientId));
      expect(presenceEntry['data'], equals('hello'));
    });
  });
}
