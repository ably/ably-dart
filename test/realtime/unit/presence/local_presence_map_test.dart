import 'package:ably_dart/ably_dart.dart';
import 'package:test/test.dart';

/// LocalPresenceMap Tests
///
/// Spec points: RTP17, RTP17b, RTP17h
///
/// Spec: uts/test/realtime/unit/presence/local_presence_map.md
void main() {
  group('LocalPresenceMap', () {
    group('RTP17h - Keyed by clientId, not memberKey', () {
      test('same clientId with different connectionId overwrites', () {
        final map = LocalPresenceMap();
        map.put(
          PresenceMessage(
            action: PresenceAction.enter,
            clientId: 'user-1',
            connectionId: 'conn-A',
            id: 'conn-A:0:0',
            timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
            data: 'first',
          ),
        );
        map.put(
          PresenceMessage(
            action: PresenceAction.enter,
            clientId: 'user-1',
            connectionId: 'conn-B',
            id: 'conn-B:0:0',
            timestamp: DateTime.fromMillisecondsSinceEpoch(2000),
            data: 'second',
          ),
        );

        // Only one entry — keyed by clientId, second put overwrites
        expect(map.values().length, equals(1));
        expect(map.get('user-1'), isNotNull);
        expect(map.get('user-1')!.data, equals('second'));
        expect(map.get('user-1')!.connectionId, equals('conn-B'));
      });
    });

    group('RTP17b - ENTER adds to map', () {
      test('ENTER event stores member', () {
        final map = LocalPresenceMap();
        map.put(
          PresenceMessage(
            action: PresenceAction.enter,
            clientId: 'client-1',
            connectionId: 'conn-1',
            id: 'conn-1:0:0',
            timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
            data: 'hello',
          ),
        );

        expect(map.get('client-1'), isNotNull);
        expect(map.get('client-1')!.action, equals(PresenceAction.present));
        expect(map.get('client-1')!.data, equals('hello'));
        expect(map.values().length, equals(1));
      });
    });

    group('RTP17b - UPDATE with no prior entry adds to map', () {
      test('UPDATE on unknown clientId behaves like ENTER', () {
        final map = LocalPresenceMap();
        map.put(
          PresenceMessage(
            action: PresenceAction.update,
            clientId: 'client-1',
            connectionId: 'conn-1',
            id: 'conn-1:0:0',
            timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
            data: 'from-update',
          ),
        );

        expect(map.get('client-1'), isNotNull);
        expect(map.get('client-1')!.action, equals(PresenceAction.present));
        expect(map.get('client-1')!.data, equals('from-update'));
        expect(map.values().length, equals(1));
      });
    });

    group('RTP17b - ENTER after ENTER overwrites', () {
      test('second ENTER for same clientId overwrites first', () {
        final map = LocalPresenceMap();
        map.put(
          PresenceMessage(
            action: PresenceAction.enter,
            clientId: 'client-1',
            connectionId: 'conn-1',
            id: 'conn-1:0:0',
            timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
            data: 'first',
          ),
        );
        map.put(
          PresenceMessage(
            action: PresenceAction.enter,
            clientId: 'client-1',
            connectionId: 'conn-1',
            id: 'conn-1:1:0',
            timestamp: DateTime.fromMillisecondsSinceEpoch(2000),
            data: 'second',
          ),
        );

        expect(map.values().length, equals(1));
        expect(map.get('client-1')!.action, equals(PresenceAction.present));
        expect(map.get('client-1')!.data, equals('second'));
      });
    });

    group('RTP17b - UPDATE after ENTER overwrites', () {
      test('UPDATE overwrites prior ENTER for same clientId', () {
        final map = LocalPresenceMap();
        map.put(
          PresenceMessage(
            action: PresenceAction.enter,
            clientId: 'client-1',
            connectionId: 'conn-1',
            id: 'conn-1:0:0',
            timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
            data: 'initial',
          ),
        );
        map.put(
          PresenceMessage(
            action: PresenceAction.update,
            clientId: 'client-1',
            connectionId: 'conn-1',
            id: 'conn-1:1:0',
            timestamp: DateTime.fromMillisecondsSinceEpoch(2000),
            data: 'updated',
          ),
        );

        expect(map.values().length, equals(1));
        expect(map.get('client-1')!.action, equals(PresenceAction.present));
        expect(map.get('client-1')!.data, equals('updated'));
      });
    });

    group('RTP17b - PRESENT adds to map', () {
      test('PRESENT event stores member', () {
        final map = LocalPresenceMap();
        map.put(
          PresenceMessage(
            action: PresenceAction.present,
            clientId: 'client-1',
            connectionId: 'conn-1',
            id: 'conn-1:0:0',
            timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
            data: 'present',
          ),
        );

        expect(map.get('client-1'), isNotNull);
        expect(map.get('client-1')!.action, equals(PresenceAction.present));
        expect(map.get('client-1')!.data, equals('present'));
      });
    });

    group('RTP17b - Non-synthesized LEAVE removes from map', () {
      test('non-synthesized LEAVE removes member', () {
        final map = LocalPresenceMap();
        map.put(
          PresenceMessage(
            action: PresenceAction.enter,
            clientId: 'client-1',
            connectionId: 'conn-1',
            id: 'conn-1:0:0',
            timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
          ),
        );
        expect(map.get('client-1'), isNotNull);

        // Non-synthesized LEAVE: connectionId "conn-1" IS prefix of id "conn-1:1:0"
        final result = map.remove(
          PresenceMessage(
            action: PresenceAction.leave,
            clientId: 'client-1',
            connectionId: 'conn-1',
            id: 'conn-1:1:0',
            timestamp: DateTime.fromMillisecondsSinceEpoch(2000),
          ),
        );

        expect(result, isTrue);
        expect(map.get('client-1'), isNull);
        expect(map.values(), isEmpty);
      });
    });

    group('RTP17b - Synthesized LEAVE is ignored', () {
      test('synthesized LEAVE does not remove member', () {
        final map = LocalPresenceMap();
        map.put(
          PresenceMessage(
            action: PresenceAction.enter,
            clientId: 'client-1',
            connectionId: 'conn-1',
            id: 'conn-1:0:0',
            timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
            data: 'entered',
          ),
        );

        // Synthesized LEAVE: connectionId "conn-1" is NOT prefix of "synthesized-leave-id"
        final result = map.remove(
          PresenceMessage(
            action: PresenceAction.leave,
            clientId: 'client-1',
            connectionId: 'conn-1',
            id: 'synthesized-leave-id',
            timestamp: DateTime.fromMillisecondsSinceEpoch(2000),
          ),
        );

        expect(result, isFalse);
        expect(map.get('client-1'), isNotNull);
        expect(map.get('client-1')!.data, equals('entered'));
        expect(map.values().length, equals(1));
      });
    });

    group('RTP17 - Multiple clientIds coexist', () {
      test('different clientIds stored independently', () {
        final map = LocalPresenceMap();
        map.put(
          PresenceMessage(
            action: PresenceAction.enter,
            clientId: 'alice',
            connectionId: 'conn-1',
            id: 'conn-1:0:0',
            timestamp: DateTime.fromMillisecondsSinceEpoch(100),
            data: 'alice-data',
          ),
        );
        map.put(
          PresenceMessage(
            action: PresenceAction.enter,
            clientId: 'bob',
            connectionId: 'conn-1',
            id: 'conn-1:0:1',
            timestamp: DateTime.fromMillisecondsSinceEpoch(100),
            data: 'bob-data',
          ),
        );
        map.put(
          PresenceMessage(
            action: PresenceAction.enter,
            clientId: 'carol',
            connectionId: 'conn-1',
            id: 'conn-1:0:2',
            timestamp: DateTime.fromMillisecondsSinceEpoch(100),
            data: 'carol-data',
          ),
        );

        expect(map.values().length, equals(3));
        expect(map.get('alice'), isNotNull);
        expect(map.get('bob'), isNotNull);
        expect(map.get('carol'), isNotNull);
        expect(map.get('alice')!.data, equals('alice-data'));
        expect(map.get('bob')!.data, equals('bob-data'));
        expect(map.get('carol')!.data, equals('carol-data'));
      });

      test('remove one of multiple members', () {
        final map = LocalPresenceMap();
        map.put(
          PresenceMessage(
            action: PresenceAction.enter,
            clientId: 'alice',
            connectionId: 'conn-1',
            id: 'conn-1:0:0',
            timestamp: DateTime.fromMillisecondsSinceEpoch(100),
          ),
        );
        map.put(
          PresenceMessage(
            action: PresenceAction.enter,
            clientId: 'bob',
            connectionId: 'conn-1',
            id: 'conn-1:0:1',
            timestamp: DateTime.fromMillisecondsSinceEpoch(100),
          ),
        );

        map.remove(
          PresenceMessage(
            action: PresenceAction.leave,
            clientId: 'alice',
            connectionId: 'conn-1',
            id: 'conn-1:1:0',
            timestamp: DateTime.fromMillisecondsSinceEpoch(200),
          ),
        );

        expect(map.get('alice'), isNull);
        expect(map.get('bob'), isNotNull);
        expect(map.values().length, equals(1));
      });
    });

    group('clear() resets all state', () {
      test('clears all members', () {
        final map = LocalPresenceMap();
        map.put(
          PresenceMessage(
            action: PresenceAction.enter,
            clientId: 'alice',
            connectionId: 'conn-1',
            id: 'conn-1:0:0',
            timestamp: DateTime.fromMillisecondsSinceEpoch(100),
          ),
        );
        map.put(
          PresenceMessage(
            action: PresenceAction.enter,
            clientId: 'bob',
            connectionId: 'conn-1',
            id: 'conn-1:0:1',
            timestamp: DateTime.fromMillisecondsSinceEpoch(100),
          ),
        );
        expect(map.values().length, equals(2));

        map.clear();

        expect(map.values(), isEmpty);
        expect(map.get('alice'), isNull);
        expect(map.get('bob'), isNull);
      });
    });

    group('RTP17 - Get returns null for unknown clientId', () {
      test('get for nonexistent clientId returns null', () {
        final map = LocalPresenceMap();
        expect(map.get('nonexistent'), isNull);
      });
    });

    group('RTP17 - Remove for unknown clientId is a no-op', () {
      test('remove for unknown clientId does not affect existing members', () {
        final map = LocalPresenceMap();
        map.put(
          PresenceMessage(
            action: PresenceAction.enter,
            clientId: 'alice',
            connectionId: 'conn-1',
            id: 'conn-1:0:0',
            timestamp: DateTime.fromMillisecondsSinceEpoch(100),
          ),
        );

        // Remove a clientId that was never added (non-synthesized leave)
        map.remove(
          PresenceMessage(
            action: PresenceAction.leave,
            clientId: 'nonexistent',
            connectionId: 'conn-1',
            id: 'conn-1:1:0',
            timestamp: DateTime.fromMillisecondsSinceEpoch(200),
          ),
        );

        expect(map.get('alice'), isNotNull);
        expect(map.values().length, equals(1));
      });
    });
  });
}
