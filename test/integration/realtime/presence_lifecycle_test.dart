import 'dart:async';
import 'dart:math';
import 'package:test/test.dart';
import 'package:ably_dart/ably_dart.dart';

import '../../helpers/test_app_helper.dart';

/// Integration tests for Realtime presence lifecycle.
///
/// These tests run against the Ably Sandbox environment with two connections
/// to verify end-to-end presence behavior: enter, update, leave, subscribe, get.
///
/// Spec: uts/test/realtime/integration/presence_lifecycle_test.md
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

  group(
      'RTP4, RTP6, RTP11a - Bulk enterClient observed on different connection',
      () {
    test('50 members entered on client A, observed on client B', () async {
      final channelName = _uniqueChannelName('presence-bulk');
      const memberCount = 50;

      final clientA = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      final clientB = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      try {
        // Connect both clients
        clientA.connect();
        await _awaitConnectionState(
            clientA.connection, ConnectionState.connected);
        clientB.connect();
        await _awaitConnectionState(
            clientB.connection, ConnectionState.connected);

        // Attach both to the channel — client B first so it's subscribed
        // before client A enters
        final channelA = clientA.channels.get(channelName);
        final channelB = clientB.channels.get(channelName);
        await channelB.attach();

        // Subscribe on client B
        final receivedEnters = <PresenceMessage>[];
        channelB.presence.subscribe(
          (event) => receivedEnters.add(event),
          action: PresenceAction.enter,
        );

        await channelA.attach();

        // Client A enters members in parallel
        final enterFutures = <Future<void>>[];
        for (var i = 0; i < memberCount; i++) {
          enterFutures.add(channelA.presence.enterClient('user-$i', 'data-$i'));
        }
        await Future.wait(enterFutures);

        // Wait for client B to receive all ENTER events
        await _pollUntil(
          () => receivedEnters.length >= memberCount,
          timeout: const Duration(seconds: 15),
        );

        // Client B gets all members
        final members = await channelB.presence.get();

        // Client B received all ENTER events via subscribe
        expect(receivedEnters.length, equals(memberCount));

        // All members present via get()
        expect(members.length, equals(memberCount));

        // Verify each member has correct clientId and data
        for (var i = 0; i < memberCount; i++) {
          final member = members.where((m) => m.clientId == 'user-$i');
          expect(member.isNotEmpty, isTrue,
              reason: 'Member user-$i should be present');
          expect(member.first.data, equals('data-$i'));
        }
      } finally {
        await clientA.close();
        await clientB.close();
      }
    });
  });

  group('RTP8, RTP9, RTP10 - Enter, update, leave lifecycle', () {
    test('complete lifecycle observed on different connection', () async {
      final channelName = _uniqueChannelName('presence-lifecycle');

      final clientA = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          clientId: 'lifecycle-client',
          useBinaryProtocol: false,
        ),
      );

      final clientB = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      try {
        // Connect and attach both clients
        clientA.connect();
        await _awaitConnectionState(
            clientA.connection, ConnectionState.connected);
        clientB.connect();
        await _awaitConnectionState(
            clientB.connection, ConnectionState.connected);

        final channelA = clientA.channels.get(channelName);
        final channelB = clientB.channels.get(channelName);
        await channelB.attach();

        // Collect all presence events on client B
        final allEvents = <PresenceMessage>[];
        channelB.presence.subscribe((event) => allEvents.add(event));

        await channelA.attach();

        // --- Phase 1: Enter ---
        await channelA.presence.enter('hello');

        await _pollUntil(
          () => allEvents.length >= 1,
          timeout: const Duration(seconds: 10),
        );

        // Verify member is present via get()
        final membersAfterEnter = await channelB.presence.get();
        expect(membersAfterEnter.length, equals(1));
        expect(membersAfterEnter[0].clientId, equals('lifecycle-client'));
        expect(membersAfterEnter[0].data, equals('hello'));

        // --- Phase 2: Update ---
        await channelA.presence.update('world');

        await _pollUntil(
          () => allEvents.length >= 2,
          timeout: const Duration(seconds: 10),
        );

        // Verify member data updated via get()
        final membersAfterUpdate = await channelB.presence.get();
        expect(membersAfterUpdate.length, equals(1));
        expect(membersAfterUpdate[0].data, equals('world'));

        // --- Phase 3: Leave ---
        await channelA.presence.leave('goodbye');

        await _pollUntil(
          () => allEvents.length >= 3,
          timeout: const Duration(seconds: 10),
        );

        // Verify member is gone via get()
        final membersAfterLeave = await channelB.presence.get();
        expect(membersAfterLeave.length, equals(0));

        // Verify the sequence of events
        expect(allEvents.length, greaterThanOrEqualTo(3));

        final enterEvent = allEvents[0];
        expect(enterEvent.action, equals(PresenceAction.enter));
        expect(enterEvent.clientId, equals('lifecycle-client'));
        expect(enterEvent.data, equals('hello'));

        final updateEvent = allEvents[1];
        expect(updateEvent.action, equals(PresenceAction.update));
        expect(updateEvent.clientId, equals('lifecycle-client'));
        expect(updateEvent.data, equals('world'));

        final leaveEvent = allEvents[2];
        expect(leaveEvent.action, equals(PresenceAction.leave));
        expect(leaveEvent.clientId, equals('lifecycle-client'));
        expect(leaveEvent.data, equals('goodbye'));
      } finally {
        await clientA.close();
        await clientB.close();
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

/// Polls a condition until it returns true, with configurable interval and timeout.
Future<void> _pollUntil(
  bool Function() condition, {
  Duration interval = const Duration(milliseconds: 200),
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException(
        'Condition not met within ${timeout.inSeconds}s',
        timeout,
      );
    }
    await Future<void>.delayed(interval);
  }
}
