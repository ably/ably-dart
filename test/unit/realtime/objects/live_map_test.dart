import 'package:test/test.dart';

import 'package:ably_dart/src/realtime/live_map.dart';
import 'package:ably_dart/src/realtime/object_message.dart';

/// LiveMap Tests
///
/// Spec points: RTLM1, RTLM2, RTLM3, RTLM4, RTLM6, RTLM6i, RTLM7, RTLM8,
///              RTLM9, RTLM9f, RTLM14, RTLM15, RTLM16, RTLM17, RTLM18,
///              RTLM19, RTLM22, RTLM24, RTLM25, RTLO3, RTLO4a, RTLO4e, RTLO5
///
/// Spec: uts/test/realtime/unit/objects/live_map.md
void main() {
  group('LiveMap', () {
    group('RTLM4 - Zero-value LiveMap', () {
      test('has empty data, objectId set, not tombstoned', () {
        final map = LiveMap(objectId: 'root');

        expect(map.objectId, equals('root'));
        expect(map.isTombstone, isFalse);
        expect(map.createOperationIsMerged, isFalse);
        expect(map.siteTimeserials, isEmpty);
        expect(map.size(), equals(0));
      });
    });

    group('RTLM7 - MAP_SET creates new entry', () {
      test('creates a new ObjectsMapEntry for non-existent key', () {
        final map = LiveMap(objectId: 'root');

        final update = map.applyOperation(
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'name',
                data: ObjectData(string: 'Alice'),
              ),
            ),
          ),
        );

        final entry = map.getEntry('name');
        expect(entry, isNotNull);
        expect(entry!.data!.string, equals('Alice'));
        expect(entry.timeserial, equals('01'));
        expect(entry.tombstone, isFalse);
        expect(map.size(), equals(1));
        expect(update, isNotNull);
        expect(update!.update['name'], equals('updated'));
      });
    });

    group('RTLM7 - MAP_SET updates existing entry', () {
      test('replaces data and timeserial on existing key', () {
        final map = LiveMap(objectId: 'root');

        map.applyOperation(
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'color',
                data: ObjectData(string: 'red'),
              ),
            ),
          ),
        );

        final update = map.applyOperation(
          ObjectMessage(
            serial: '02',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'color',
                data: ObjectData(string: 'blue'),
              ),
            ),
          ),
        );

        expect(map.getEntry('color')!.data!.string, equals('blue'));
        expect(map.getEntry('color')!.timeserial, equals('02'));
        expect(
          update!.update['color'],
          equals('updated'),
        );
      });
    });

    group('RTLM7 - MAP_SET with different data types', () {
      test('stores number, boolean, and objectId data types', () {
        final map = LiveMap(objectId: 'root');

        map.applyOperation(
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'count',
                data: ObjectData(number: 42),
              ),
            ),
          ),
        );

        map.applyOperation(
          ObjectMessage(
            serial: '02',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'active',
                data: ObjectData(boolean: true),
              ),
            ),
          ),
        );

        map.applyOperation(
          ObjectMessage(
            serial: '03',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'child',
                data: ObjectData(objectId: 'map:xyz@1000'),
              ),
            ),
          ),
        );

        expect(map.getEntry('count')!.data!.number, equals(42));
        expect(map.getEntry('active')!.data!.boolean, isTrue);
        expect(
          map.getEntry('child')!.data!.objectId,
          equals('map:xyz@1000'),
        );
        expect(map.size(), equals(3));
      });
    });

    group('RTLM9 - MAP_SET rejected when serial not newer (LWW)', () {
      test(
        'entry-level LWW rejects MAP_SET with older serial than entry',
        () {
          final map = LiveMap(objectId: 'root');

          // Set entry with serial "05"
          map.applyOperation(
            ObjectMessage(
              serial: '05',
              siteCode: 'site1',
              operation: ObjectOperation(
                action: ObjectOperationAction.mapSet,
                objectId: 'root',
                mapOp: ObjectsMapOp(
                  key: 'x',
                  data: ObjectData(string: 'first'),
                ),
              ),
            ),
          );

          // Operation from different site with serial "03" passes
          // canApplyOperation (no siteSerial for site2 yet) but
          // entry timeserial "05" > "03" so entry-level check fails
          final update = map.applyOperation(
            ObjectMessage(
              serial: '03',
              siteCode: 'site2',
              operation: ObjectOperation(
                action: ObjectOperationAction.mapSet,
                objectId: 'root',
                mapOp: ObjectsMapOp(
                  key: 'x',
                  data: ObjectData(string: 'stale'),
                ),
              ),
            ),
          );

          expect(map.getEntry('x')!.data!.string, equals('first'));
          expect(update, isNotNull);
          expect(update!.noop, isTrue);
        },
      );
    });

    group('RTLM8 - MAP_REMOVE tombstones an entry', () {
      test('sets tombstone to true and data to null', () {
        final map = LiveMap(objectId: 'root');

        // Add an entry
        map.applyOperation(
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'name',
                data: ObjectData(string: 'Alice'),
              ),
            ),
          ),
        );

        // Remove it
        final update = map.applyOperation(
          ObjectMessage(
            serial: '02',
            siteCode: 'site1',
            serialTimestamp: 5000,
            operation: ObjectOperation(
              action: ObjectOperationAction.mapRemove,
              objectId: 'root',
              mapOp: ObjectsMapOp(key: 'name'),
            ),
          ),
        );

        final entry = map.getEntry('name');
        expect(entry, isNotNull);
        expect(entry!.tombstone, isTrue);
        expect(entry.data, isNull);
        expect(entry.timeserial, equals('02'));
        expect(entry.tombstonedAt, equals(5000));
        expect(map.size(), equals(0));
        expect(
          update!.update['name'],
          equals('removed'),
        );
      });
    });

    group('RTLM8 - MAP_REMOVE on non-existent key creates tombstone', () {
      test('creates a tombstoned entry for a missing key', () {
        final map = LiveMap(objectId: 'root');

        final update = map.applyOperation(
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
            serialTimestamp: 2000,
            operation: ObjectOperation(
              action: ObjectOperationAction.mapRemove,
              objectId: 'root',
              mapOp: ObjectsMapOp(key: 'nonexistent'),
            ),
          ),
        );

        final entry = map.getEntry('nonexistent');
        expect(entry, isNotNull);
        expect(entry!.tombstone, isTrue);
        expect(entry.data, isNull);
        expect(entry.tombstonedAt, equals(2000));
        expect(
          update!.update['nonexistent'],
          equals('removed'),
        );
      });
    });

    group('RTLM9 - MAP_REMOVE rejected when serial not newer', () {
      test('entry-level LWW rejects MAP_REMOVE with older serial', () {
        final map = LiveMap(objectId: 'root');

        // Set entry with serial "05"
        map.applyOperation(
          ObjectMessage(
            serial: '05',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'x',
                data: ObjectData(string: 'keep'),
              ),
            ),
          ),
        );

        // Try MAP_REMOVE from different site with serial "03"
        // canApplyOperation passes (site2 has no siteSerial), but
        // entry check fails because "03" < "05"
        final update = map.applyOperation(
          ObjectMessage(
            serial: '03',
            siteCode: 'site2',
            serialTimestamp: 9000,
            operation: ObjectOperation(
              action: ObjectOperationAction.mapRemove,
              objectId: 'root',
              mapOp: ObjectsMapOp(key: 'x'),
            ),
          ),
        );

        expect(map.getEntry('x')!.tombstone, isFalse);
        expect(map.getEntry('x')!.data!.string, equals('keep'));
        expect(update!.noop, isTrue);
      });
    });

    group('RTLM7a2c - MAP_SET un-tombstones an entry', () {
      test('sets tombstone to false and tombstonedAt to null', () {
        final map = LiveMap(objectId: 'root');

        // Set then remove
        map.applyOperation(
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'x',
                data: ObjectData(string: 'first'),
              ),
            ),
          ),
        );
        map.applyOperation(
          ObjectMessage(
            serial: '02',
            siteCode: 'site1',
            serialTimestamp: 1000,
            operation: ObjectOperation(
              action: ObjectOperationAction.mapRemove,
              objectId: 'root',
              mapOp: ObjectsMapOp(key: 'x'),
            ),
          ),
        );

        // Re-set with newer serial
        final update = map.applyOperation(
          ObjectMessage(
            serial: '03',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'x',
                data: ObjectData(string: 'revived'),
              ),
            ),
          ),
        );

        final entry = map.getEntry('x');
        expect(entry!.tombstone, isFalse);
        expect(entry.tombstonedAt, isNull);
        expect(entry.data!.string, equals('revived'));
        expect(map.size(), equals(1));
        expect(
          update!.update['x'],
          equals('updated'),
        );
      });
    });

    group('RTLM16, RTLM17 - MAP_CREATE merges initial entries', () {
      test('applies initial entries and sets createOperationIsMerged', () {
        final map = LiveMap(objectId: 'root');

        final update = map.applyOperation(
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapCreate,
              objectId: 'root',
              map: ObjectsMap(
                entries: {
                  'a': ObjectsMapEntry(
                    data: ObjectData(string: 'hello'),
                    timeserial: '01',
                  ),
                  'b': ObjectsMapEntry(
                    data: ObjectData(number: 42),
                    timeserial: '01',
                  ),
                },
              ),
            ),
          ),
        );

        expect(map.createOperationIsMerged, isTrue);
        expect(map.getEntry('a')!.data!.string, equals('hello'));
        expect(map.getEntry('b')!.data!.number, equals(42));
        expect(map.size(), equals(2));
        expect(
          update!.update['a'],
          equals('updated'),
        );
        expect(update.update['b'], equals('updated'));
      });
    });

    group('RTLM16b - Duplicate MAP_CREATE is noop', () {
      test('second MAP_CREATE is ignored when already merged', () {
        final map = LiveMap(objectId: 'root');

        map.applyOperation(
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapCreate,
              objectId: 'root',
              map: ObjectsMap(
                entries: {
                  'a': ObjectsMapEntry(
                    data: ObjectData(string: 'first'),
                    timeserial: '01',
                  ),
                },
              ),
            ),
          ),
        );

        final update = map.applyOperation(
          ObjectMessage(
            serial: '02',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapCreate,
              objectId: 'root',
              map: ObjectsMap(
                entries: {
                  'b': ObjectsMapEntry(
                    data: ObjectData(string: 'second'),
                    timeserial: '02',
                  ),
                },
              ),
            ),
          ),
        );

        expect(map.getEntry('a')!.data!.string, equals('first'));
        expect(map.getEntry('b'), isNull);
        expect(update!.noop, isTrue);
      });
    });

    group('RTLM17a2 - MAP_CREATE with tombstoned entries', () {
      test('tombstoned entries in create are applied as MAP_REMOVE', () {
        final map = LiveMap(objectId: 'root');

        final update = map.applyOperation(
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapCreate,
              objectId: 'root',
              map: ObjectsMap(
                entries: {
                  'alive': ObjectsMapEntry(
                    data: ObjectData(string: 'yes'),
                    timeserial: '01',
                  ),
                  'dead': ObjectsMapEntry(
                    timeserial: '01',
                    tombstone: true,
                    tombstonedAt: 1000,
                  ),
                },
              ),
            ),
          ),
        );

        expect(map.getEntry('alive')!.tombstone, isFalse);
        expect(map.getEntry('dead')!.tombstone, isTrue);
        expect(map.size(), equals(1));
        expect(
          update!.update['alive'],
          equals('updated'),
        );
        expect(update.update['dead'], equals('removed'));
      });
    });

    group('RTLO5, RTLM15d5 - OBJECT_DELETE tombstones the map', () {
      test('sets isTombstone, clears data, emits removed keys', () {
        final map = LiveMap(objectId: 'root');

        // Add entries
        map.applyOperation(
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'a',
                data: ObjectData(string: 'one'),
              ),
            ),
          ),
        );
        map.applyOperation(
          ObjectMessage(
            serial: '02',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'b',
                data: ObjectData(string: 'two'),
              ),
            ),
          ),
        );

        // Delete
        final update = map.applyOperation(
          ObjectMessage(
            serial: '03',
            siteCode: 'site1',
            serialTimestamp: 5000,
            operation: ObjectOperation(
              action: ObjectOperationAction.objectDelete,
              objectId: 'root',
            ),
          ),
        );

        expect(map.isTombstone, isTrue);
        expect(map.tombstonedAt, equals(5000));
        expect(map.size(), equals(0));
        expect(
          update!.update['a'],
          equals('removed'),
        );
        expect(update.update['b'], equals('removed'));
      });
    });

    group('RTLM15e - Operation on tombstoned map is ignored', () {
      test('MAP_SET after OBJECT_DELETE returns null', () {
        final map = LiveMap(objectId: 'map:abc@1000');

        // Tombstone the map
        map.applyOperation(
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
            serialTimestamp: 1000,
            operation: ObjectOperation(
              action: ObjectOperationAction.objectDelete,
              objectId: 'map:abc@1000',
            ),
          ),
        );

        // Try MAP_SET -- should be ignored
        final update = map.applyOperation(
          ObjectMessage(
            serial: '02',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'map:abc@1000',
              mapOp: ObjectsMapOp(
                key: 'x',
                data: ObjectData(string: 'nope'),
              ),
            ),
          ),
        );

        expect(map.size(), equals(0));
        expect(update, isNull);
      });
    });

    group('RTLM6 - replaceData sets map from ObjectState', () {
      test('replaces siteTimeserials, resets data, calculates diff', () {
        final map = LiveMap(objectId: 'root');

        // Pre-populate
        map.applyOperation(
          ObjectMessage(
            serial: '01',
            siteCode: 'oldsite',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'old',
                data: ObjectData(string: 'data'),
              ),
            ),
          ),
        );

        final update = map.replaceData(
          ObjectState(
            objectId: 'root',
            siteTimeserials: {'newsite': '50'},
            map: ObjectsMap(
              entries: {
                'new': ObjectsMapEntry(
                  data: ObjectData(string: 'fresh'),
                  timeserial: '50',
                ),
              },
            ),
          ),
          ObjectMessage(serial: '50', siteCode: 'newsite'),
        );

        expect(map.getEntry('old'), isNull);
        expect(map.getEntry('new')!.data!.string, equals('fresh'));
        expect(map.siteTimeserials, equals({'newsite': '50'}));
        expect(map.createOperationIsMerged, isFalse);
        expect(map.size(), equals(1));
        expect(update.update['old'], equals('removed'));
        expect(update.update['new'], equals('updated'));
      });
    });

    group('RTLM6d - replaceData merges createOp', () {
      test('createOp entries merged after ObjectState entries', () {
        final map = LiveMap(objectId: 'root');

        map.replaceData(
          ObjectState(
            objectId: 'root',
            siteTimeserials: {'site1': '10'},
            map: ObjectsMap(
              entries: {
                'x': ObjectsMapEntry(
                  data: ObjectData(number: 1),
                  timeserial: '05',
                ),
              },
            ),
            createOp: ObjectOperation(
              action: ObjectOperationAction.mapCreate,
              objectId: 'root',
              map: ObjectsMap(
                entries: {
                  'x': ObjectsMapEntry(
                    data: ObjectData(number: 99),
                    timeserial: '10',
                  ),
                  'y': ObjectsMapEntry(
                    data: ObjectData(string: 'new'),
                    timeserial: '10',
                  ),
                },
              ),
            ),
          ),
          ObjectMessage(serial: '10', siteCode: 'site1'),
        );

        // createOp entry for "x" has timeserial "10" > existing "05", wins
        expect(map.getEntry('x')!.data!.number, equals(99));
        // "y" is new from createOp
        expect(map.getEntry('y')!.data!.string, equals('new'));
        expect(map.createOperationIsMerged, isTrue);
        expect(map.size(), equals(2));
      });
    });

    group('RTLM6e - replaceData on tombstoned map is noop', () {
      test('only updates siteTimeserials, returns noop', () {
        final map = LiveMap(objectId: 'map:abc@1000');

        // Tombstone it
        map.applyOperation(
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
            serialTimestamp: 1000,
            operation: ObjectOperation(
              action: ObjectOperationAction.objectDelete,
              objectId: 'map:abc@1000',
            ),
          ),
        );

        final update = map.replaceData(
          ObjectState(
            objectId: 'map:abc@1000',
            siteTimeserials: {'site2': '99'},
            map: ObjectsMap(
              entries: {
                'a': ObjectsMapEntry(
                  data: ObjectData(string: 'ignored'),
                  timeserial: '99',
                ),
              },
            ),
          ),
          ObjectMessage(serial: '99', siteCode: 'site2'),
        );

        expect(map.size(), equals(0));
        expect(map.isTombstone, isTrue);
        expect(map.siteTimeserials, equals({'site2': '99'}));
        expect(update.noop, isTrue);
      });
    });

    group('RTLM6f - replaceData with tombstone ObjectState', () {
      test('tombstones the map and returns removed keys', () {
        final map = LiveMap(objectId: 'root');

        map.applyOperation(
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'k',
                data: ObjectData(string: 'val'),
              ),
            ),
          ),
        );

        final update = map.replaceData(
          ObjectState(
            objectId: 'root',
            siteTimeserials: {'site1': '05'},
            tombstone: true,
          ),
          ObjectMessage(
            serial: '05',
            siteCode: 'site1',
            serialTimestamp: 3000,
          ),
        );

        expect(map.isTombstone, isTrue);
        expect(map.tombstonedAt, equals(3000));
        expect(map.size(), equals(0));
        expect(update.update['k'], equals('removed'));
      });
    });

    group('RTLM22 - Diff calculation between previous and new data', () {
      test('computes removed, updated, new, and unchanged correctly', () {
        final map = LiveMap(objectId: 'root');

        // Set up initial state: a=1, b=2, c=3
        map.applyOperation(
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'a',
                data: ObjectData(number: 1),
              ),
            ),
          ),
        );
        map.applyOperation(
          ObjectMessage(
            serial: '02',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'b',
                data: ObjectData(number: 2),
              ),
            ),
          ),
        );
        map.applyOperation(
          ObjectMessage(
            serial: '03',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'c',
                data: ObjectData(number: 3),
              ),
            ),
          ),
        );

        // Replace: a=1 (same), b removed, c=99 (changed), d=4 (new)
        final update = map.replaceData(
          ObjectState(
            objectId: 'root',
            siteTimeserials: {'site1': '10'},
            map: ObjectsMap(
              entries: {
                'a': ObjectsMapEntry(
                  data: ObjectData(number: 1),
                  timeserial: '10',
                ),
                'c': ObjectsMapEntry(
                  data: ObjectData(number: 99),
                  timeserial: '10',
                ),
                'd': ObjectsMapEntry(
                  data: ObjectData(number: 4),
                  timeserial: '10',
                ),
              },
            ),
          ),
          ObjectMessage(serial: '10', siteCode: 'site1'),
        );

        expect(update.update['b'], equals('removed'));
        expect(update.update['c'], equals('updated'));
        expect(update.update['d'], equals('updated'));
        // "a" not in update (unchanged)
        expect(update.update.containsKey('a'), isFalse);
      });
    });

    group('RTLM19 - Tombstoned entries removed after grace period', () {
      test('GC removes entries past grace period, keeps live ones', () {
        final map = LiveMap(objectId: 'root');

        // Add and tombstone an entry at time 1000
        map.applyOperation(
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'temp',
                data: ObjectData(string: 'gone'),
              ),
            ),
          ),
        );
        map.applyOperation(
          ObjectMessage(
            serial: '02',
            siteCode: 'site1',
            serialTimestamp: 1000,
            operation: ObjectOperation(
              action: ObjectOperationAction.mapRemove,
              objectId: 'root',
              mapOp: ObjectsMapOp(key: 'temp'),
            ),
          ),
        );

        // Also add a live entry
        map.applyOperation(
          ObjectMessage(
            serial: '03',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'alive',
                data: ObjectData(string: 'here'),
              ),
            ),
          ),
        );

        // GC with currentTime=200000, gracePeriod=120000 (2 min)
        // temp tombstonedAt=1000, age=199000 >= 120000 -> remove
        map.gcTombstonedEntries(currentTime: 200000, gracePeriod: 120000);

        expect(map.getEntry('temp'), isNull);
        expect(map.getEntry('alive'), isNotNull);
      });
    });

    group('RTLM15d4 - Unsupported action is ignored', () {
      test('operation with unsupported action returns null', () {
        final map = LiveMap(objectId: 'root');

        final update = map.applyOperation(
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.counterInc,
              objectId: 'root',
            ),
          ),
        );

        expect(update, isNull);
        expect(map.size(), equals(0));
      });
    });

    group('RTLM15b, RTLO4a - Stale operation rejected (same site)', () {
      test('older serial from same site is rejected at object level', () {
        final map = LiveMap(objectId: 'root');

        map.applyOperation(
          ObjectMessage(
            serial: '05',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'x',
                data: ObjectData(string: 'first'),
              ),
            ),
          ),
        );

        final update = map.applyOperation(
          ObjectMessage(
            serial: '03',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'y',
                data: ObjectData(string: 'stale'),
              ),
            ),
          ),
        );

        expect(map.getEntry('y'), isNull);
        expect(update, isNull);
      });
    });

    group('keys() and size() exclude tombstoned entries', () {
      test('only non-tombstoned entries are counted and listed', () {
        final map = LiveMap(objectId: 'root');

        map.applyOperation(
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'a',
                data: ObjectData(string: 'one'),
              ),
            ),
          ),
        );
        map.applyOperation(
          ObjectMessage(
            serial: '02',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'b',
                data: ObjectData(string: 'two'),
              ),
            ),
          ),
        );
        map.applyOperation(
          ObjectMessage(
            serial: '03',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'c',
                data: ObjectData(string: 'three'),
              ),
            ),
          ),
        );

        // Tombstone "b"
        map.applyOperation(
          ObjectMessage(
            serial: '04',
            siteCode: 'site1',
            serialTimestamp: 1000,
            operation: ObjectOperation(
              action: ObjectOperationAction.mapRemove,
              objectId: 'root',
              mapOp: ObjectsMapOp(key: 'b'),
            ),
          ),
        );

        expect(map.size(), equals(2));
        final keysList = map.keys().toList();
        expect(keysList, contains('a'));
        expect(keysList, contains('c'));
        expect(keysList, isNot(contains('b')));
      });
    });

    group('RTLM25 - MAP_CLEAR removes entries with older serials', () {
      test('tombstones all entries with serial <= clear serial', () {
        final map = LiveMap(objectId: 'root');

        // Add entries at serials "01", "02", "03"
        map.applyOperation(
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'a',
                data: ObjectData(string: 'one'),
              ),
            ),
          ),
        );
        map.applyOperation(
          ObjectMessage(
            serial: '02',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'b',
                data: ObjectData(string: 'two'),
              ),
            ),
          ),
        );
        map.applyOperation(
          ObjectMessage(
            serial: '03',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'c',
                data: ObjectData(string: 'three'),
              ),
            ),
          ),
        );

        // MAP_CLEAR at serial "05"
        final update = map.applyOperation(
          ObjectMessage(
            serial: '05',
            siteCode: 'site1',
            serialTimestamp: 5000,
            operation: ObjectOperation(
              action: ObjectOperationAction.mapClear,
              objectId: 'root',
            ),
          ),
        );

        expect(map.size(), equals(0));
        expect(map.clearSerial, equals('05'));
        expect(map.getEntry('a'), isNull);
        expect(map.getEntry('b'), isNull);
        expect(map.getEntry('c'), isNull);
        expect(update!.update['a'], equals('removed'));
        expect(update.update['b'], equals('removed'));
        expect(update.update['c'], equals('removed'));
        expect(update.noop, isFalse);
      });
    });

    group('RTLM25e - MAP_CLEAR preserves entries with newer serials', () {
      test('entries with serial > clear serial are not affected', () {
        final map = LiveMap(objectId: 'root');

        // Add entry at serial "03" and another at serial "07"
        map.applyOperation(
          ObjectMessage(
            serial: '03',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'old',
                data: ObjectData(string: 'gone'),
              ),
            ),
          ),
        );
        map.applyOperation(
          ObjectMessage(
            serial: '07',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'new',
                data: ObjectData(string: 'kept'),
              ),
            ),
          ),
        );

        // MAP_CLEAR at serial "05"
        final update = map.applyOperation(
          ObjectMessage(
            serial: '05',
            siteCode: 'site2',
            serialTimestamp: 5000,
            operation: ObjectOperation(
              action: ObjectOperationAction.mapClear,
              objectId: 'root',
            ),
          ),
        );

        expect(map.size(), equals(1));
        expect(map.getEntry('old'), isNull);
        expect(map.getEntry('new')!.tombstone, isFalse);
        expect(map.getEntry('new')!.data!.string, equals('kept'));
        expect(update!.update['old'], equals('removed'));
        expect(update.update.containsKey('new'), isFalse);
      });
    });

    group(
      'RTLM25b - MAP_CLEAR with older serial than clearSerial is noop',
      () {
        test('stale MAP_CLEAR does not update clearSerial', () {
          final map = LiveMap(objectId: 'root');

          // First clear at serial "05"
          map.applyOperation(
            ObjectMessage(
              serial: '05',
              siteCode: 'site1',
              serialTimestamp: 5000,
              operation: ObjectOperation(
                action: ObjectOperationAction.mapClear,
                objectId: 'root',
              ),
            ),
          );

          // Second clear at serial "03" — stale, should be noop
          final staleUpdate = map.applyOperation(
            ObjectMessage(
              serial: '03',
              siteCode: 'site2',
              serialTimestamp: 3000,
              operation: ObjectOperation(
                action: ObjectOperationAction.mapClear,
                objectId: 'root',
              ),
            ),
          );

          expect(map.clearSerial, equals('05'));
          expect(staleUpdate!.noop, isTrue);
        });
      },
    );

    group('RTLM9f - MAP_SET rejected when serial <= clearSerial', () {
      test('clearSerial floor blocks stale MAP_SET', () {
        final map = LiveMap(objectId: 'root');

        // MAP_CLEAR at serial "05"
        map.applyOperation(
          ObjectMessage(
            serial: '05',
            siteCode: 'site1',
            serialTimestamp: 5000,
            operation: ObjectOperation(
              action: ObjectOperationAction.mapClear,
              objectId: 'root',
            ),
          ),
        );

        // MAP_SET from different site, serial "03" — passes object-level
        // check (site2 has no prior siteSerial) but fails clearSerial floor
        final update = map.applyOperation(
          ObjectMessage(
            serial: '03',
            siteCode: 'site2',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'x',
                data: ObjectData(string: 'stale'),
              ),
            ),
          ),
        );

        expect(map.getEntry('x'), isNull);
        expect(update!.noop, isTrue);
      });
    });

    group('RTLM9f - MAP_SET accepted when serial > clearSerial', () {
      test('operations with serial > clearSerial proceed normally', () {
        final map = LiveMap(objectId: 'root');

        // MAP_CLEAR at serial "05"
        map.applyOperation(
          ObjectMessage(
            serial: '05',
            siteCode: 'site1',
            serialTimestamp: 5000,
            operation: ObjectOperation(
              action: ObjectOperationAction.mapClear,
              objectId: 'root',
            ),
          ),
        );

        // MAP_SET at serial "07" — accepted
        final update = map.applyOperation(
          ObjectMessage(
            serial: '07',
            siteCode: 'site2',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'x',
                data: ObjectData(string: 'fresh'),
              ),
            ),
          ),
        );

        expect(map.getEntry('x')!.data!.string, equals('fresh'));
        expect(map.getEntry('x')!.tombstone, isFalse);
        expect(update!.noop, isFalse);
        expect(update.update['x'], equals('updated'));
      });
    });

    group('RTLM9f - MAP_REMOVE rejected when serial <= clearSerial', () {
      test('clearSerial floor blocks stale MAP_REMOVE', () {
        final map = LiveMap(objectId: 'root');

        // Add an entry and then clear
        map.applyOperation(
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'x',
                data: ObjectData(string: 'val'),
              ),
            ),
          ),
        );
        map.applyOperation(
          ObjectMessage(
            serial: '05',
            siteCode: 'site1',
            serialTimestamp: 5000,
            operation: ObjectOperation(
              action: ObjectOperationAction.mapClear,
              objectId: 'root',
            ),
          ),
        );

        // MAP_REMOVE from different site at serial "03" — rejected
        final update = map.applyOperation(
          ObjectMessage(
            serial: '03',
            siteCode: 'site2',
            serialTimestamp: 3000,
            operation: ObjectOperation(
              action: ObjectOperationAction.mapRemove,
              objectId: 'root',
              mapOp: ObjectsMapOp(key: 'y'),
            ),
          ),
        );

        expect(update!.noop, isTrue);
      });
    });

    group('RTLM25 - MAP_CLEAR on empty map sets clearSerial', () {
      test('clearSerial updated even with no entries to remove', () {
        final map = LiveMap(objectId: 'root');

        final update = map.applyOperation(
          ObjectMessage(
            serial: '05',
            siteCode: 'site1',
            serialTimestamp: 5000,
            operation: ObjectOperation(
              action: ObjectOperationAction.mapClear,
              objectId: 'root',
            ),
          ),
        );

        expect(map.clearSerial, equals('05'));
        expect(map.size(), equals(0));
        expect(update!.update, isEmpty);
        expect(update.noop, isFalse);
      });
    });

    group('RTLM6i - replaceData restores clearSerial from ObjectState', () {
      test('clearSerial from ObjectState blocks stale operations', () {
        final map = LiveMap(objectId: 'root');

        map.replaceData(
          ObjectState(
            objectId: 'root',
            siteTimeserials: {'site1': '10'},
            clearSerial: '05',
            map: ObjectsMap(
              entries: {
                'x': ObjectsMapEntry(
                  data: ObjectData(string: 'val'),
                  timeserial: '10',
                ),
              },
            ),
          ),
          ObjectMessage(serial: '10', siteCode: 'site1'),
        );

        expect(map.clearSerial, equals('05'));
        expect(map.getEntry('x')!.data!.string, equals('val'));

        // Try MAP_SET with serial "03" from different site — rejected
        final staleUpdate = map.applyOperation(
          ObjectMessage(
            serial: '03',
            siteCode: 'site2',
            operation: ObjectOperation(
              action: ObjectOperationAction.mapSet,
              objectId: 'root',
              mapOp: ObjectsMapOp(
                key: 'y',
                data: ObjectData(string: 'stale'),
              ),
            ),
          ),
        );

        expect(staleUpdate!.noop, isTrue);
        expect(map.getEntry('y'), isNull);
      });
    });
  });
}
