import 'dart:async';
import 'dart:math';
import 'package:test/test.dart';
import 'package:ably_dart/ably_dart.dart';

import '../../helpers/test_app_helper.dart';

/// Integration tests for REST batchPresence (RSC24).
///
/// These tests run against the Ably Sandbox environment. A Realtime client
/// enters presence members, then a REST client calls batchPresence to
/// verify the response format and content.
///
/// Uses ably-common test-app-setup.json:
///   keys[0] — full access (default capability)
///   keys[2] — per-channel capabilities, "channel6":["*"] used as restricted key
///
/// Spec: uts/test/rest/integration/batch_presence.md
void main() {
  late TestApp testApp;
  late String fullAccessKey;
  late String restrictedKey;

  // Channel name matching keys[2] capability from ably-common.
  const allowedChannel = 'channel6';

  setUpAll(() async {
    testApp = await TestApp.provision();
    fullAccessKey = testApp.keys[0].keyStr;
    restrictedKey = testApp.keys[2].keyStr;
    print('Provisioned test app: ${testApp.appId}');
  });

  tearDownAll(() async {
    await testApp.delete();
    print('Deleted test app: ${testApp.appId}');
  });

  group(
    'RSC24, BGR2 - batchPresence returns members across multiple channels',
    () {
      test('members on two channels returned in single batch request',
          () async {
        final channelAName = _uniqueChannelName('batch-presence-a');
        final channelBName = _uniqueChannelName('batch-presence-b');

        // Enter members via Realtime
        final realtime = Realtime(
          options: ClientOptions(
            key: fullAccessKey,
            environment: 'sandbox',
            useBinaryProtocol: false,
          ),
        );

        try {
          realtime.connect();
          await _awaitConnectionState(
            realtime.connection,
            ConnectionState.connected,
          );

          final chA = realtime.channels.get(channelAName);
          await chA.attach();
          await chA.presence.enterClient('user-1', 'data-a1');
          await chA.presence.enterClient('user-2', 'data-a2');

          final chB = realtime.channels.get(channelBName);
          await chB.attach();
          await chB.presence.enterClient('user-3', 'data-b1');

          // Query via REST batchPresence
          final rest = Rest(
            options: ClientOptions(
              key: fullAccessKey,
              environment: 'sandbox',
              useBinaryProtocol: false,
            ),
          );

          try {
            final result =
                await rest.batchPresence([channelAName, channelBName]);

            // Verify computed counts (BAR2)
            expect(result.successCount, equals(2));
            expect(result.failureCount, equals(0));
            expect(result.results.length, equals(2));

            // Find results by channel name
            final resultA =
                result.results.firstWhere((r) => r.channel == channelAName);
            final resultB =
                result.results.firstWhere((r) => r.channel == channelBName);

            // Channel A: 2 members (BGR2)
            expect(resultA, isA<BatchPresenceSuccessResult>());
            final successA = resultA as BatchPresenceSuccessResult;
            expect(successA.presence.length, equals(2));

            final clientIdsA = successA.presence.map((m) => m.clientId).toSet();
            expect(clientIdsA, contains('user-1'));
            expect(clientIdsA, contains('user-2'));

            // Verify data round-trips
            final member1 =
                successA.presence.firstWhere((m) => m.clientId == 'user-1');
            expect(member1.data, equals('data-a1'));

            // Channel B: 1 member
            expect(resultB, isA<BatchPresenceSuccessResult>());
            final successB = resultB as BatchPresenceSuccessResult;
            expect(successB.presence.length, equals(1));
            expect(successB.presence[0].clientId, equals('user-3'));
            expect(successB.presence[0].data, equals('data-b1'));
          } finally {
            await rest.close();
          }
        } finally {
          await realtime.close();
        }
      });
    },
  );

  group('RSC24, BGF2 - Restricted key returns per-channel failure', () {
    test('allowed channel succeeds, denied channel fails', () async {
      final deniedChannel = _uniqueChannelName('denied-batch');

      // Enter members on both channels using full-access key
      final realtime = Realtime(
        options: ClientOptions(
          key: fullAccessKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      try {
        realtime.connect();
        await _awaitConnectionState(
          realtime.connection,
          ConnectionState.connected,
        );

        final chAllowed = realtime.channels.get(allowedChannel);
        await chAllowed.attach();
        await chAllowed.presence.enterClient('member-1', 'hello');

        final chDenied = realtime.channels.get(deniedChannel);
        await chDenied.attach();
        await chDenied.presence.enterClient('member-2', 'world');

        await realtime.close();

        // Query with restricted key (only has access to "batch-allowed")
        final restrictedRest = Rest(
          options: ClientOptions(
            key: restrictedKey,
            environment: 'sandbox',
            useBinaryProtocol: false,
          ),
        );

        try {
          final result = await restrictedRest
              .batchPresence([allowedChannel, deniedChannel]);

          expect(result.successCount, equals(1));
          expect(result.failureCount, equals(1));
          expect(result.results.length, equals(2));

          // Find results by channel
          final success =
              result.results.firstWhere((r) => r.channel == allowedChannel);
          final failure =
              result.results.firstWhere((r) => r.channel == deniedChannel);

          // Allowed channel succeeds with presence data
          expect(success, isA<BatchPresenceSuccessResult>());
          final successResult = success as BatchPresenceSuccessResult;
          expect(successResult.presence.length, equals(1));
          expect(successResult.presence[0].clientId, equals('member-1'));

          // Denied channel fails with capability error
          expect(failure, isA<BatchPresenceFailureResult>());
          final failureResult = failure as BatchPresenceFailureResult;
          expect(failureResult.error, isA<ErrorInfo>());
          expect(failureResult.error.code, equals(40160));
          expect(failureResult.error.statusCode, equals(401));
        } finally {
          await restrictedRest.close();
        }
      } finally {
        try {
          await realtime.close();
        } catch (_) {}
      }
    });
  });

  group('RSC24 - Empty channel returns empty presence array', () {
    test('empty and populated channels in same batch', () async {
      final emptyChannel = _uniqueChannelName('batch-empty');
      final populatedChannel = _uniqueChannelName('batch-populated');

      // Enter a member on only the populated channel
      final realtime = Realtime(
        options: ClientOptions(
          key: fullAccessKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      try {
        realtime.connect();
        await _awaitConnectionState(
          realtime.connection,
          ConnectionState.connected,
        );

        final ch = realtime.channels.get(populatedChannel);
        await ch.attach();
        await ch.presence.enterClient('someone', 'here');

        // Query both channels (keep realtime open so presence persists)
        final rest = Rest(
          options: ClientOptions(
            key: fullAccessKey,
            environment: 'sandbox',
            useBinaryProtocol: false,
          ),
        );

        try {
          final result =
              await rest.batchPresence([emptyChannel, populatedChannel]);

          expect(result.successCount, equals(2));
          expect(result.failureCount, equals(0));
          expect(result.results.length, equals(2));

          final emptyResult =
              result.results.firstWhere((r) => r.channel == emptyChannel);
          final populatedResult =
              result.results.firstWhere((r) => r.channel == populatedChannel);

          // Empty channel succeeds with no members
          expect(emptyResult, isA<BatchPresenceSuccessResult>());
          expect(
            (emptyResult as BatchPresenceSuccessResult).presence.length,
            equals(0),
          );

          // Populated channel succeeds with the member
          expect(populatedResult, isA<BatchPresenceSuccessResult>());
          final popSuccess = populatedResult as BatchPresenceSuccessResult;
          expect(popSuccess.presence.length, equals(1));
          expect(popSuccess.presence[0].clientId, equals('someone'));
        } finally {
          await rest.close();
        }
      } finally {
        await realtime.close();
      }
    });
  });
}

/// Generates a unique channel name for test isolation.
String _uniqueChannelName(String prefix) {
  final random = Random().nextInt(999999).toString().padLeft(6, '0');
  return '$prefix-$random';
}

/// Waits for connection to reach the specified state.
Future<void> _awaitConnectionState(
  Connection connection,
  ConnectionState targetState, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  if (connection.state == targetState) return;

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
