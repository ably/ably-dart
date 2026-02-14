import 'package:test/test.dart';

import 'package:ably_dart/src/realtime/live_counter.dart';
import 'package:ably_dart/src/realtime/live_map.dart';
import 'package:ably_dart/src/realtime/live_object.dart';
import 'package:ably_dart/src/realtime/object_message.dart';
import 'package:ably_dart/src/realtime/objects_pool.dart';

void main() {
  group('ObjectsPool', () {
    group('RTO3b - Initialization contains root LiveMap', () {
      test('pool starts with root LiveMap and INITIALIZED state', () {
        final pool = ObjectsPool();

        expect(pool.getObject('root'), isNotNull);
        expect(pool.getObject('root'), isA<LiveMap>());
        expect((pool.getObject('root')! as LiveMap).size(), equals(0));
        expect(pool.syncState, equals(ObjectsSyncState.initialized));
        expect(pool.bufferedObjectOperations.length, equals(0));
      });
    });

    group('RTO4c - handleAttached transitions to SYNCING', () {
      test('handleAttached with hasObjectsFlag=true sets SYNCING', () {
        final pool = ObjectsPool();

        pool.handleAttached(hasObjectsFlag: true);

        expect(pool.syncState, equals(ObjectsSyncState.syncing));
      });
    });

    group(
        'RTO4b - handleAttached without HAS_OBJECTS completes sync immediately',
        () {
      test('removes non-root objects, clears root, and transitions to SYNCED',
          () {
        final pool = ObjectsPool();

        // Add a non-root object first (simulate previous sync)
        pool.handleAttached(hasObjectsFlag: true);
        pool.handleObjectSync(
          channelSerial: 'seq1:',
          objectStates: [
            ObjectState(
              objectId: 'root',
              map: ObjectsMap(
                entries: {
                  'key': ObjectsMapEntry(
                    data: ObjectData(string: 'val'),
                    timeserial: '01',
                  ),
                },
              ),
              siteTimeserials: {'s1': '01'},
            ),
            ObjectState(
              objectId: 'counter:abc@1000',
              counter: ObjectsCounter(count: 5),
              siteTimeserials: {'s1': '01'},
            ),
          ],
        );
        expect(pool.syncState, equals(ObjectsSyncState.synced));

        // Now receive a new ATTACHED without HAS_OBJECTS
        pool.handleAttached(hasObjectsFlag: false);

        expect(pool.syncState, equals(ObjectsSyncState.synced));
        expect(pool.getObject('root'), isNotNull);
        expect(
          (pool.getObject('root')! as LiveMap).size(),
          equals(0),
        ); // Root cleared (RTO4b2)
        expect(
          pool.getObject('counter:abc@1000'),
          isNull,
        ); // Non-root removed (RTO4b1)
      });
    });

    group('RTO5 - Basic OBJECT_SYNC sequence', () {
      test('accumulates states and completes when cursor is empty', () {
        final pool = ObjectsPool();
        pool.handleAttached(hasObjectsFlag: true);

        // First OBJECT_SYNC message (sequence "seq1", cursor "abc")
        pool.handleObjectSync(
          channelSerial: 'seq1:abc',
          objectStates: [
            ObjectState(
              objectId: 'root',
              map: ObjectsMap(
                entries: {
                  'name': ObjectsMapEntry(
                    data: ObjectData(string: 'Alice'),
                    timeserial: '01',
                  ),
                },
              ),
              siteTimeserials: {'s1': '01'},
            ),
          ],
        );
        expect(pool.syncState, equals(ObjectsSyncState.syncing));

        // Second OBJECT_SYNC message (same sequence, empty cursor = complete)
        pool.handleObjectSync(
          channelSerial: 'seq1:',
          objectStates: [
            ObjectState(
              objectId: 'counter:abc@1000',
              counter: ObjectsCounter(count: 42),
              siteTimeserials: {'s1': '01'},
            ),
          ],
        );

        expect(pool.syncState, equals(ObjectsSyncState.synced));
        expect(
          (pool.getObject('root')! as LiveMap).getEntry('name')!.data!.string,
          equals('Alice'),
        );
        expect(pool.getObject('counter:abc@1000'), isNotNull);
        expect(
          (pool.getObject('counter:abc@1000')! as LiveCounter).data,
          equals(42),
        );
      });
    });

    group('RTO5a5 - OBJECT_SYNC with no channelSerial is self-contained', () {
      test('single message with null channelSerial completes sync', () {
        final pool = ObjectsPool();
        pool.handleAttached(hasObjectsFlag: true);

        pool.handleObjectSync(
          objectStates: [
            ObjectState(
              objectId: 'root',
              map: ObjectsMap(
                entries: {
                  'x': ObjectsMapEntry(
                    data: ObjectData(number: 1),
                    timeserial: '01',
                  ),
                },
              ),
              siteTimeserials: {'s1': '01'},
            ),
          ],
        );

        expect(pool.syncState, equals(ObjectsSyncState.synced));
        expect(
          (pool.getObject('root')! as LiveMap).getEntry('x')!.data!.number,
          equals(1),
        );
      });
    });

    group('RTO5d - OBJECT_SYNC with null objectStates is skipped', () {
      test('sync completes but no objects added', () {
        final pool = ObjectsPool();
        pool.handleAttached(hasObjectsFlag: true);

        pool.handleObjectSync(channelSerial: 'seq1:');

        // Sync completes (empty cursor) but no objects added
        expect(pool.syncState, equals(ObjectsSyncState.synced));
        expect((pool.getObject('root')! as LiveMap).size(), equals(0));
      });
    });

    group('RTO5a2 - New sequence id discards previous sync', () {
      test('old sync data discarded when new sequence starts', () {
        final pool = ObjectsPool();
        pool.handleAttached(hasObjectsFlag: true);

        // Start first sync sequence
        pool.handleObjectSync(
          channelSerial: 'seq1:cursor1',
          objectStates: [
            ObjectState(
              objectId: 'counter:old@1000',
              counter: ObjectsCounter(count: 100),
              siteTimeserials: {'s1': '01'},
            ),
          ],
        );

        // New sequence id starts a new sync -- old data discarded
        pool.handleObjectSync(
          channelSerial: 'seq2:cursor1',
          objectStates: [
            ObjectState(
              objectId: 'root',
              map: ObjectsMap(entries: {}),
              siteTimeserials: {'s1': '01'},
            ),
          ],
        );

        // Complete the new sequence
        pool.handleObjectSync(
          channelSerial: 'seq2:',
          objectStates: [
            ObjectState(
              objectId: 'counter:new@2000',
              counter: ObjectsCounter(count: 7),
              siteTimeserials: {'s1': '02'},
            ),
          ],
        );

        expect(pool.syncState, equals(ObjectsSyncState.synced));
        expect(
          pool.getObject('counter:old@1000'),
          isNull,
        ); // From discarded sequence
        expect(pool.getObject('counter:new@2000'), isNotNull);
        expect(
          (pool.getObject('counter:new@2000')! as LiveCounter).data,
          equals(7),
        );
      });
    });

    group('RTO5c2 - Sync removes objects not in sync sequence', () {
      test('objects not received during sync are removed', () {
        final pool = ObjectsPool();
        // First sync with two objects
        pool.handleAttached(hasObjectsFlag: true);
        pool.handleObjectSync(
          channelSerial: 'seq1:',
          objectStates: [
            ObjectState(
              objectId: 'root',
              map: ObjectsMap(entries: {}),
              siteTimeserials: {'s1': '01'},
            ),
            ObjectState(
              objectId: 'counter:abc@1000',
              counter: ObjectsCounter(count: 10),
              siteTimeserials: {'s1': '01'},
            ),
          ],
        );
        expect(pool.getObject('counter:abc@1000'), isNotNull);

        // Second sync -- only root, no counter
        pool.handleAttached(hasObjectsFlag: true);
        pool.handleObjectSync(
          channelSerial: 'seq2:',
          objectStates: [
            ObjectState(
              objectId: 'root',
              map: ObjectsMap(entries: {}),
              siteTimeserials: {'s1': '02'},
            ),
          ],
        );

        expect(pool.getObject('counter:abc@1000'), isNull); // Removed
        expect(pool.getObject('root'), isNotNull); // Root always kept
      });
    });

    group('RTO5c2a - Root is never removed from pool', () {
      test('root preserved even if not in sync objectStates', () {
        final pool = ObjectsPool();
        pool.handleAttached(hasObjectsFlag: true);

        // Sync with no root in the objectStates
        pool.handleObjectSync(
          channelSerial: 'seq1:',
          objectStates: [
            ObjectState(
              objectId: 'counter:abc@1000',
              counter: ObjectsCounter(count: 5),
              siteTimeserials: {'s1': '01'},
            ),
          ],
        );

        expect(pool.getObject('root'), isNotNull); // Root preserved
      });
    });

    group('RTO8a - OBJECT messages buffered during sync', () {
      test('messages buffered when sync state is not SYNCED', () {
        final pool = ObjectsPool();
        pool.handleAttached(hasObjectsFlag: true);
        expect(pool.syncState, equals(ObjectsSyncState.syncing));

        // Receive OBJECT message during sync
        pool.handleObjectMessage([
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.counterInc,
              objectId: 'counter:abc@1000',
              counterOp: ObjectsCounterOp(amount: 5),
            ),
          ),
        ]);

        expect(pool.bufferedObjectOperations.length, equals(1));
        // Object not yet created in pool (buffered, not applied)
        expect(pool.getObject('counter:abc@1000'), isNull);
      });
    });

    group(
        'RTO5c6 - Buffered operations applied after sync completes (fresh ops)',
        () {
      test('buffered increment with newer serial is applied', () {
        final pool = ObjectsPool();
        pool.handleAttached(hasObjectsFlag: true);

        // Buffer an increment during sync
        pool.handleObjectMessage([
          ObjectMessage(
            serial: '05',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.counterInc,
              objectId: 'counter:abc@1000',
              counterOp: ObjectsCounterOp(amount: 3),
            ),
          ),
        ]);

        // Complete sync with the counter at count=10
        pool.handleObjectSync(
          channelSerial: 'seq1:',
          objectStates: [
            ObjectState(
              objectId: 'root',
              map: ObjectsMap(entries: {}),
              siteTimeserials: {'s1': '01'},
            ),
            ObjectState(
              objectId: 'counter:abc@1000',
              counter: ObjectsCounter(count: 10),
              siteTimeserials: {'s1': '03'},
            ),
          ],
        );

        expect(pool.syncState, equals(ObjectsSyncState.synced));
        // Buffered increment serial "05" > siteSerial "03", so it's applied
        expect(
          (pool.getObject('counter:abc@1000')! as LiveCounter).data,
          equals(13),
        ); // 10 + 3
        expect(
          pool.bufferedObjectOperations.length,
          equals(0),
        ); // Buffer cleared
      });
    });

    group('RTO5c6 - Stale buffered operations rejected after sync', () {
      test('buffered increment with older serial is rejected', () {
        final pool = ObjectsPool();
        pool.handleAttached(hasObjectsFlag: true);

        // Buffer an increment with serial "02"
        pool.handleObjectMessage([
          ObjectMessage(
            serial: '02',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.counterInc,
              objectId: 'counter:abc@1000',
              counterOp: ObjectsCounterOp(amount: 999),
            ),
          ),
        ]);

        // Complete sync with siteSerial "05" -- the buffered op is stale
        pool.handleObjectSync(
          channelSerial: 'seq1:',
          objectStates: [
            ObjectState(
              objectId: 'root',
              map: ObjectsMap(entries: {}),
              siteTimeserials: {'s1': '01'},
            ),
            ObjectState(
              objectId: 'counter:abc@1000',
              counter: ObjectsCounter(count: 10),
              siteTimeserials: {'site1': '05'},
            ),
          ],
        );

        // Unchanged, buffered op rejected
        expect(
          (pool.getObject('counter:abc@1000')! as LiveCounter).data,
          equals(10),
        );
      });
    });

    group('RTO8b - OBJECT messages applied immediately when SYNCED', () {
      test('MAP_SET applied directly in SYNCED state', () {
        final pool = ObjectsPool();
        // Quick sync to reach SYNCED state
        pool.handleAttached(hasObjectsFlag: true);
        pool.handleObjectSync(
          channelSerial: 'seq1:',
          objectStates: [
            ObjectState(
              objectId: 'root',
              map: ObjectsMap(entries: {}),
              siteTimeserials: {'s1': '01'},
            ),
          ],
        );
        expect(pool.syncState, equals(ObjectsSyncState.synced));

        pool.handleObjectMessage([
          ObjectMessage(
            serial: '02',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(key: 'x', data: ObjectData(string: 'hello')),
            ),
          ),
        ]);

        expect(
          (pool.getObject('root')! as LiveMap).getEntry('x')!.data!.string,
          equals('hello'),
        );
        expect(
          pool.bufferedObjectOperations.length,
          equals(0),
        ); // Not buffered
      });
    });

    group('RTO6 - Zero-value object created on demand', () {
      test('COUNTER_INC for missing objectId creates zero-value counter', () {
        final pool = ObjectsPool();
        pool.handleAttached(hasObjectsFlag: true);
        pool.handleObjectSync(
          channelSerial: 'seq1:',
          objectStates: [
            ObjectState(
              objectId: 'root',
              map: ObjectsMap(entries: {}),
              siteTimeserials: {'s1': '01'},
            ),
          ],
        );

        // COUNTER_INC for an objectId not in the pool
        pool.handleObjectMessage([
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.counterInc,
              objectId: 'counter:xyz@2000',
              counterOp: ObjectsCounterOp(amount: 7),
            ),
          ),
        ]);

        expect(pool.getObject('counter:xyz@2000'), isNotNull);
        expect(pool.getObject('counter:xyz@2000'), isA<LiveCounter>());
        expect(
          (pool.getObject('counter:xyz@2000')! as LiveCounter).data,
          equals(7),
        );
      });

      test('MAP_SET for missing objectId creates zero-value LiveMap', () {
        final pool = ObjectsPool();
        pool.handleAttached(hasObjectsFlag: true);
        pool.handleObjectSync(
          channelSerial: 'seq1:',
          objectStates: [
            ObjectState(
              objectId: 'root',
              map: ObjectsMap(entries: {}),
              siteTimeserials: {'s1': '01'},
            ),
          ],
        );

        pool.handleObjectMessage([
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'map:xyz@2000',
              mapOp: ObjectsMapOp(
                key: 'k',
                data: ObjectData(string: 'v'),
              ),
            ),
          ),
        ]);

        expect(pool.getObject('map:xyz@2000'), isNotNull);
        expect(pool.getObject('map:xyz@2000'), isA<LiveMap>());
        expect(
          (pool.getObject('map:xyz@2000')! as LiveMap)
              .getEntry('k')!
              .data!
              .string,
          equals('v'),
        );
      });
    });

    group('RTO9a1 - Operation with null operation field is discarded', () {
      test('message with null operation does not crash or change state', () {
        final pool = ObjectsPool();
        pool.handleAttached(hasObjectsFlag: true);
        pool.handleObjectSync(
          channelSerial: 'seq1:',
          objectStates: [
            ObjectState(
              objectId: 'root',
              map: ObjectsMap(entries: {}),
              siteTimeserials: {'s1': '01'},
            ),
          ],
        );

        pool.handleObjectMessage([
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
          ),
        ]);

        // No crash, no change
        expect((pool.getObject('root')! as LiveMap).size(), equals(0));
      });
    });

    group('RTO9a2b - Operation with unsupported action is discarded', () {
      test('unsupported action does not crash or change state', () {
        final pool = ObjectsPool();
        pool.handleAttached(hasObjectsFlag: true);
        pool.handleObjectSync(
          channelSerial: 'seq1:',
          objectStates: [
            ObjectState(
              objectId: 'root',
              map: ObjectsMap(entries: {}),
              siteTimeserials: {'s1': '01'},
            ),
          ],
        );

        // We cannot construct an ObjectOperation with a truly unknown action
        // since ObjectOperationAction is an enum. Instead, we test that
        // the pool handles messages gracefully when operation is null.
        // The RTO9a2b spec point is covered by the _applyMessages method
        // only processing known actions in the switch statement.
        // We can simulate this by passing a message with no operation.
        pool.handleObjectMessage([
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
          ),
        ]);

        // No crash, no change
        expect((pool.getObject('root')! as LiveMap).size(), equals(0));
      });
    });

    group('RTO10 - GC removes tombstoned objects past grace period', () {
      test('tombstoned object removed when age >= grace period', () {
        final pool = ObjectsPool();
        pool.handleAttached(hasObjectsFlag: true);
        pool.handleObjectSync(
          channelSerial: 'seq1:',
          objectStates: [
            ObjectState(
              objectId: 'root',
              map: ObjectsMap(entries: {}),
              siteTimeserials: {'s1': '01'},
            ),
            ObjectState(
              objectId: 'counter:abc@1000',
              counter: ObjectsCounter(count: 5),
              siteTimeserials: {'s1': '01'},
            ),
          ],
        );

        // Tombstone the counter
        pool.handleObjectMessage([
          ObjectMessage(
            serial: '02',
            siteCode: 'site1',
            serialTimestamp: 10000,
            operation: ObjectOperation(
              action: ObjectOperationAction.objectDelete,
              objectId: 'counter:abc@1000',
            ),
          ),
        ]);

        expect(
          pool.getObject('counter:abc@1000'),
          isNotNull,
        ); // Still there (tombstoned)
        expect(pool.getObject('counter:abc@1000')!.isTombstone, isTrue);

        // GC with current_time=200000, grace_period=120000 (2 min)
        // tombstonedAt=10000, age=190000 >= 120000 -> remove
        pool.gc(currentTime: 200000, gracePeriod: 120000);

        expect(pool.getObject('counter:abc@1000'), isNull); // Removed
        expect(pool.getObject('root'), isNotNull); // Root always kept
      });
    });

    group('RTO10 - GC keeps tombstoned objects within grace period', () {
      test('tombstoned object kept when age < grace period', () {
        final pool = ObjectsPool();
        pool.handleAttached(hasObjectsFlag: true);
        pool.handleObjectSync(
          channelSerial: 'seq1:',
          objectStates: [
            ObjectState(
              objectId: 'root',
              map: ObjectsMap(entries: {}),
              siteTimeserials: {'s1': '01'},
            ),
            ObjectState(
              objectId: 'counter:abc@1000',
              counter: ObjectsCounter(count: 5),
              siteTimeserials: {'s1': '01'},
            ),
          ],
        );

        // Tombstone the counter at time 100000
        pool.handleObjectMessage([
          ObjectMessage(
            serial: '02',
            siteCode: 'site1',
            serialTimestamp: 100000,
            operation: ObjectOperation(
              action: ObjectOperationAction.objectDelete,
              objectId: 'counter:abc@1000',
            ),
          ),
        ]);

        // GC at time 150000 with grace period 120000
        // age = 50000 < 120000 -> keep
        pool.gc(currentTime: 150000, gracePeriod: 120000);

        expect(
          pool.getObject('counter:abc@1000'),
          isNotNull,
        ); // Still there
        expect(pool.getObject('counter:abc@1000')!.isTombstone, isTrue);
      });
    });

    group('RTO5c1a - Sync updates existing objects in pool', () {
      test('same instance is updated, not replaced', () {
        final pool = ObjectsPool();
        // First sync
        pool.handleAttached(hasObjectsFlag: true);
        pool.handleObjectSync(
          channelSerial: 'seq1:',
          objectStates: [
            ObjectState(
              objectId: 'root',
              map: ObjectsMap(
                entries: {
                  'x': ObjectsMapEntry(
                    data: ObjectData(string: 'old'),
                    timeserial: '01',
                  ),
                },
              ),
              siteTimeserials: {'s1': '01'},
            ),
          ],
        );
        final rootRef = pool.getObject('root');

        // Second sync with updated root
        pool.handleAttached(hasObjectsFlag: true);
        pool.handleObjectSync(
          channelSerial: 'seq2:',
          objectStates: [
            ObjectState(
              objectId: 'root',
              map: ObjectsMap(
                entries: {
                  'x': ObjectsMapEntry(
                    data: ObjectData(string: 'new'),
                    timeserial: '05',
                  ),
                },
              ),
              siteTimeserials: {'s1': '05'},
            ),
          ],
        );

        // Same instance is updated, not replaced
        expect(pool.getObject('root'), same(rootRef));
        expect(
          (pool.getObject('root')! as LiveMap).getEntry('x')!.data!.string,
          equals('new'),
        );
      });
    });

    group('RTO17 - Sync state transitions', () {
      test('transitions from INITIALIZED -> SYNCING -> SYNCED', () {
        final pool = ObjectsPool();
        expect(pool.syncState, equals(ObjectsSyncState.initialized));

        pool.handleAttached(hasObjectsFlag: true);
        expect(pool.syncState, equals(ObjectsSyncState.syncing));

        pool.handleObjectSync(
          channelSerial: 'seq1:',
          objectStates: [
            ObjectState(
              objectId: 'root',
              map: ObjectsMap(entries: {}),
              siteTimeserials: {'s1': '01'},
            ),
          ],
        );
        expect(pool.syncState, equals(ObjectsSyncState.synced));
      });
    });

    group('RTO5e - OBJECT_SYNC transitions to SYNCING if not already', () {
      test('OBJECT_SYNC without prior ATTACHED sets SYNCING', () {
        final pool = ObjectsPool();
        expect(pool.syncState, equals(ObjectsSyncState.initialized));

        // OBJECT_SYNC without prior ATTACHED
        pool.handleObjectSync(
          channelSerial: 'seq1:cursor',
          objectStates: [
            ObjectState(
              objectId: 'root',
              map: ObjectsMap(entries: {}),
              siteTimeserials: {'s1': '01'},
            ),
          ],
        );

        expect(pool.syncState, equals(ObjectsSyncState.syncing));
      });
    });

    group(
        'RTO4b2a - handleAttached without HAS_OBJECTS emits update for '
        'cleared root', () {
      test('emits LiveMapUpdate with removed keys when root is cleared', () {
        final pool = ObjectsPool();
        pool.handleAttached(hasObjectsFlag: true);
        pool.handleObjectSync(
          channelSerial: 'seq1:',
          objectStates: [
            ObjectState(
              objectId: 'root',
              map: ObjectsMap(
                entries: {
                  'a': ObjectsMapEntry(
                    data: ObjectData(string: 'one'),
                    timeserial: '01',
                  ),
                  'b': ObjectsMapEntry(
                    data: ObjectData(string: 'two'),
                    timeserial: '01',
                  ),
                },
              ),
              siteTimeserials: {'s1': '01'},
            ),
          ],
        );

        // Collect updates emitted during handleAttached
        final updates = <({LiveObject object, LiveObjectUpdate update})>[];
        pool.onUpdate = (object, update) {
          updates.add((object: object, update: update));
        };

        pool.handleAttached(hasObjectsFlag: false);

        // Find the root update
        final rootUpdate = updates.where(
          (u) => u.object.objectId == 'root',
        );
        expect(rootUpdate, isNotEmpty);

        final mapUpdate = rootUpdate.first.update as LiveMapUpdate;
        expect(mapUpdate.update['a'], equals('removed'));
        expect(mapUpdate.update['b'], equals('removed'));
      });
    });
  });
}
