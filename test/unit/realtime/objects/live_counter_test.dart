import 'package:test/test.dart';

import 'package:ably_dart/src/realtime/live_counter.dart';
import 'package:ably_dart/src/realtime/object_message.dart';

/// Unit tests for LiveCounter (RTLC1, RTLC2, RTLC3, RTLC4, RTLC6, RTLC7,
/// RTLC8, RTLC9, RTLC10, RTLC14, RTLO3, RTLO4a, RTLO4e, RTLO5).
///
/// These are pure data structure tests — no mocks, no async, no connection
/// infrastructure needed.
///
/// Spec: uts/test/realtime/unit/objects/live_counter.md
void main() {
  group('RTLC4 - Zero-value LiveCounter', () {
    test('has data set to 0 and default field values', () {
      final counter = LiveCounter(objectId: 'counter:abc@1000');

      expect(counter.data, equals(0));
      expect(counter.objectId, equals('counter:abc@1000'));
      expect(counter.isTombstone, isFalse);
      expect(counter.createOperationIsMerged, isFalse);
      expect(counter.siteTimeserials, isEmpty);
    });
  });

  group('RTLC9 - COUNTER_INC adds amount to data', () {
    test('increments counter by positive amount', () {
      final counter = LiveCounter(objectId: 'counter:abc@1000');

      final update = counter.applyOperation(
        ObjectMessage(
          serial: '01',
          siteCode: 'site1',
          operation: ObjectOperation(
            action: ObjectOperationAction.counterInc,
            objectId: 'counter:abc@1000',
            counterOp: ObjectsCounterOp(amount: 5),
          ),
        ),
      );

      expect(counter.data, equals(5));
      expect(update, isNotNull);
      expect(update!.noop, isFalse);
      expect(update.amount, equals(5));
    });

    test('decrements counter with negative amount', () {
      final counter = LiveCounter(objectId: 'counter:abc@1000');

      counter.applyOperation(
        ObjectMessage(
          serial: '01',
          siteCode: 'site1',
          operation: ObjectOperation(
            action: ObjectOperationAction.counterInc,
            objectId: 'counter:abc@1000',
            counterOp: ObjectsCounterOp(amount: 10),
          ),
        ),
      );

      final update = counter.applyOperation(
        ObjectMessage(
          serial: '02',
          siteCode: 'site1',
          operation: ObjectOperation(
            action: ObjectOperationAction.counterInc,
            objectId: 'counter:abc@1000',
            counterOp: ObjectsCounterOp(amount: -3),
          ),
        ),
      );

      expect(counter.data, equals(7));
      expect(update!.amount, equals(-3));
    });

    test('accumulates increments from different sites', () {
      final counter = LiveCounter(objectId: 'counter:abc@1000');

      counter.applyOperation(
        ObjectMessage(
          serial: '01',
          siteCode: 'siteA',
          operation: ObjectOperation(
            action: ObjectOperationAction.counterInc,
            objectId: 'counter:abc@1000',
            counterOp: ObjectsCounterOp(amount: 3),
          ),
        ),
      );

      counter.applyOperation(
        ObjectMessage(
          serial: '01',
          siteCode: 'siteB',
          operation: ObjectOperation(
            action: ObjectOperationAction.counterInc,
            objectId: 'counter:abc@1000',
            counterOp: ObjectsCounterOp(amount: 7),
          ),
        ),
      );

      expect(counter.data, equals(10));
      expect(counter.siteTimeserials['siteA'], equals('01'));
      expect(counter.siteTimeserials['siteB'], equals('01'));
    });
  });

  group('RTLC9e - COUNTER_INC with missing amount is noop', () {
    test('returns noop when counterOp has no amount', () {
      final counter = LiveCounter(objectId: 'counter:abc@1000');

      final update = counter.applyOperation(
        ObjectMessage(
          serial: '01',
          siteCode: 'site1',
          operation: ObjectOperation(
            action: ObjectOperationAction.counterInc,
            objectId: 'counter:abc@1000',
            counterOp: ObjectsCounterOp(),
          ),
        ),
      );

      expect(counter.data, equals(0));
      expect(update, isNotNull);
      expect(update!.noop, isTrue);
    });
  });

  group('RTLC7c - applyOperation updates siteTimeserials', () {
    test('sets siteTimeserials entry for the operation siteCode', () {
      final counter = LiveCounter(objectId: 'counter:abc@1000');

      counter.applyOperation(
        ObjectMessage(
          serial: 'abc123',
          siteCode: 'site1',
          operation: ObjectOperation(
            action: ObjectOperationAction.counterInc,
            objectId: 'counter:abc@1000',
            counterOp: ObjectsCounterOp(amount: 1),
          ),
        ),
      );

      expect(counter.siteTimeserials['site1'], equals('abc123'));
    });
  });

  group('RTLO4a, RTLC7b - Stale operation rejected', () {
    test('rejects operation with older serial from same site', () {
      final counter = LiveCounter(objectId: 'counter:abc@1000');

      // Apply first operation with serial "05"
      counter.applyOperation(
        ObjectMessage(
          serial: '05',
          siteCode: 'site1',
          operation: ObjectOperation(
            action: ObjectOperationAction.counterInc,
            objectId: 'counter:abc@1000',
            counterOp: ObjectsCounterOp(amount: 10),
          ),
        ),
      );

      // Try to apply older operation with serial "03"
      final update = counter.applyOperation(
        ObjectMessage(
          serial: '03',
          siteCode: 'site1',
          operation: ObjectOperation(
            action: ObjectOperationAction.counterInc,
            objectId: 'counter:abc@1000',
            counterOp: ObjectsCounterOp(amount: 999),
          ),
        ),
      );

      expect(counter.data, equals(10));
      expect(update, isNull);
    });
  });

  group('RTLO4a - First operation for a site always accepted', () {
    test('accepts operation when no prior serial exists for the site', () {
      final counter = LiveCounter(objectId: 'counter:abc@1000');

      final update = counter.applyOperation(
        ObjectMessage(
          serial: '01',
          siteCode: 'newsite',
          operation: ObjectOperation(
            action: ObjectOperationAction.counterInc,
            objectId: 'counter:abc@1000',
            counterOp: ObjectsCounterOp(amount: 42),
          ),
        ),
      );

      expect(update, isNotNull);
      expect(counter.data, equals(42));
    });
  });

  group('RTLO4a - Operation with empty serial or siteCode is rejected', () {
    test('rejects operations with empty serial or empty siteCode', () {
      final counter = LiveCounter(objectId: 'counter:abc@1000');

      final resultEmptySerial = counter.applyOperation(
        ObjectMessage(
          serial: '',
          siteCode: 'site1',
          operation: ObjectOperation(
            action: ObjectOperationAction.counterInc,
            objectId: 'counter:abc@1000',
            counterOp: ObjectsCounterOp(amount: 5),
          ),
        ),
      );

      final resultEmptySiteCode = counter.applyOperation(
        ObjectMessage(
          serial: '01',
          siteCode: '',
          operation: ObjectOperation(
            action: ObjectOperationAction.counterInc,
            objectId: 'counter:abc@1000',
            counterOp: ObjectsCounterOp(amount: 5),
          ),
        ),
      );

      expect(resultEmptySerial, isNull);
      expect(resultEmptySiteCode, isNull);
      expect(counter.data, equals(0));
    });
  });

  group('RTLC8, RTLC10 - COUNTER_CREATE merges initial value', () {
    test('adds counter.count to data and sets createOperationIsMerged', () {
      final counter = LiveCounter(objectId: 'counter:abc@1000');

      final update = counter.applyOperation(
        ObjectMessage(
          serial: '01',
          siteCode: 'site1',
          operation: ObjectOperation(
            action: ObjectOperationAction.counterCreate,
            objectId: 'counter:abc@1000',
            counter: ObjectsCounter(count: 42),
          ),
        ),
      );

      expect(counter.data, equals(42));
      expect(counter.createOperationIsMerged, isTrue);
      expect(update, isNotNull);
      expect(update!.noop, isFalse);
      expect(update.amount, equals(42));
    });
  });

  group('RTLC8b - Duplicate COUNTER_CREATE is noop', () {
    test('ignores second COUNTER_CREATE when already merged', () {
      final counter = LiveCounter(objectId: 'counter:abc@1000');

      // First CREATE
      counter.applyOperation(
        ObjectMessage(
          serial: '01',
          siteCode: 'site1',
          operation: ObjectOperation(
            action: ObjectOperationAction.counterCreate,
            objectId: 'counter:abc@1000',
            counter: ObjectsCounter(count: 10),
          ),
        ),
      );

      // Second CREATE — should be noop
      final update = counter.applyOperation(
        ObjectMessage(
          serial: '02',
          siteCode: 'site1',
          operation: ObjectOperation(
            action: ObjectOperationAction.counterCreate,
            objectId: 'counter:abc@1000',
            counter: ObjectsCounter(count: 99),
          ),
        ),
      );

      expect(counter.data, equals(10));
      expect(update, isNotNull);
      expect(update!.noop, isTrue);
    });
  });

  group('RTLC10 - COUNTER_CREATE with missing count is noop', () {
    test('sets createOperationIsMerged but returns noop', () {
      final counter = LiveCounter(objectId: 'counter:abc@1000');

      final update = counter.applyOperation(
        ObjectMessage(
          serial: '01',
          siteCode: 'site1',
          operation: ObjectOperation(
            action: ObjectOperationAction.counterCreate,
            objectId: 'counter:abc@1000',
            counter: ObjectsCounter(),
          ),
        ),
      );

      expect(counter.data, equals(0));
      expect(counter.createOperationIsMerged, isTrue);
      expect(update!.noop, isTrue);
    });
  });

  group('RTLC10 - COUNTER_CREATE count adds to existing data', () {
    test('adds count to data rather than replacing it', () {
      final counter = LiveCounter(objectId: 'counter:abc@1000');

      // Simulate sync having set data to 5 first
      counter.applyOperation(
        ObjectMessage(
          serial: '01',
          siteCode: 'site1',
          operation: ObjectOperation(
            action: ObjectOperationAction.counterInc,
            objectId: 'counter:abc@1000',
            counterOp: ObjectsCounterOp(amount: 5),
          ),
        ),
      );

      // Then CREATE adds 10
      counter.applyOperation(
        ObjectMessage(
          serial: '02',
          siteCode: 'site1',
          operation: ObjectOperation(
            action: ObjectOperationAction.counterCreate,
            objectId: 'counter:abc@1000',
            counter: ObjectsCounter(count: 10),
          ),
        ),
      );

      expect(counter.data, equals(15));
    });
  });

  group('RTLO5, RTLC7d4 - OBJECT_DELETE tombstones the counter', () {
    test(
      'sets isTombstone, clears data, and returns negated previous value',
      () {
        final counter = LiveCounter(objectId: 'counter:abc@1000');

        // Set counter to 25
        counter.applyOperation(
          ObjectMessage(
            serial: '01',
            siteCode: 'site1',
            operation: ObjectOperation(
              action: ObjectOperationAction.counterInc,
              objectId: 'counter:abc@1000',
              counterOp: ObjectsCounterOp(amount: 25),
            ),
          ),
        );

        // Delete
        final update = counter.applyOperation(
          ObjectMessage(
            serial: '02',
            siteCode: 'site1',
            serialTimestamp: 5000,
            operation: ObjectOperation(
              action: ObjectOperationAction.objectDelete,
              objectId: 'counter:abc@1000',
            ),
          ),
        );

        expect(counter.isTombstone, isTrue);
        expect(counter.tombstonedAt, equals(5000));
        expect(counter.data, equals(0));
        expect(update, isNotNull);
        expect(update!.amount, equals(-25));
      },
    );
  });

  group('RTLC7e - Operation on tombstoned counter is ignored', () {
    test('returns null for operations applied to a tombstoned counter', () {
      final counter = LiveCounter(objectId: 'counter:abc@1000');

      // Tombstone the counter
      counter.applyOperation(
        ObjectMessage(
          serial: '01',
          siteCode: 'site1',
          serialTimestamp: 1000,
          operation: ObjectOperation(
            action: ObjectOperationAction.objectDelete,
            objectId: 'counter:abc@1000',
          ),
        ),
      );

      // Try to increment — should be ignored
      final update = counter.applyOperation(
        ObjectMessage(
          serial: '02',
          siteCode: 'site1',
          operation: ObjectOperation(
            action: ObjectOperationAction.counterInc,
            objectId: 'counter:abc@1000',
            counterOp: ObjectsCounterOp(amount: 10),
          ),
        ),
      );

      expect(counter.data, equals(0));
      expect(update, isNull);
    });
  });

  group('RTLC6 - replaceData sets counter from ObjectState', () {
    test('replaces siteTimeserials, resets state, and sets data', () {
      final counter = LiveCounter(objectId: 'counter:abc@1000');

      // Pre-populate with some state
      counter.applyOperation(
        ObjectMessage(
          serial: '01',
          siteCode: 'oldsite',
          operation: ObjectOperation(
            action: ObjectOperationAction.counterInc,
            objectId: 'counter:abc@1000',
            counterOp: ObjectsCounterOp(amount: 99),
          ),
        ),
      );

      final update = counter.replaceData(
        ObjectState(
          objectId: 'counter:abc@1000',
          siteTimeserials: {'newsite': '50'},
          counter: ObjectsCounter(count: 20),
        ),
        ObjectMessage(serial: '50', siteCode: 'newsite'),
      );

      expect(counter.data, equals(20));
      expect(counter.siteTimeserials, equals({'newsite': '50'}));
      expect(counter.createOperationIsMerged, isFalse);
      expect(update.noop, isFalse);
      expect(update.amount, equals(-79));
    });
  });

  group('RTLC6d - replaceData merges createOp', () {
    test('merges createOp initial value after setting data from counter', () {
      final counter = LiveCounter(objectId: 'counter:abc@1000');

      final update = counter.replaceData(
        ObjectState(
          objectId: 'counter:abc@1000',
          siteTimeserials: {'site1': '10'},
          counter: ObjectsCounter(count: 5),
          createOp: ObjectOperation(
            action: ObjectOperationAction.counterCreate,
            objectId: 'counter:abc@1000',
            counter: ObjectsCounter(count: 3),
          ),
        ),
        ObjectMessage(serial: '10', siteCode: 'site1'),
      );

      // data = counter.count (5) + createOp.counter.count (3) = 8
      expect(counter.data, equals(8));
      expect(counter.createOperationIsMerged, isTrue);
      // Update amount = final (8) - previous (0) = 8
      expect(update.amount, equals(8));
    });
  });

  group('RTLC6e - replaceData on tombstoned counter is noop', () {
    test('only updates siteTimeserials and returns noop', () {
      final counter = LiveCounter(objectId: 'counter:abc@1000');

      // Tombstone it
      counter.applyOperation(
        ObjectMessage(
          serial: '01',
          siteCode: 'site1',
          serialTimestamp: 1000,
          operation: ObjectOperation(
            action: ObjectOperationAction.objectDelete,
            objectId: 'counter:abc@1000',
          ),
        ),
      );

      final update = counter.replaceData(
        ObjectState(
          objectId: 'counter:abc@1000',
          siteTimeserials: {'site2': '99'},
          counter: ObjectsCounter(count: 50),
        ),
        ObjectMessage(serial: '99', siteCode: 'site2'),
      );

      expect(counter.data, equals(0));
      expect(counter.isTombstone, isTrue);
      expect(counter.siteTimeserials, equals({'site2': '99'}));
      expect(update.noop, isTrue);
    });
  });

  group('RTLC6f - replaceData with tombstone ObjectState', () {
    test('tombstones counter and returns negated previous value', () {
      final counter = LiveCounter(objectId: 'counter:abc@1000');

      // Set counter to 30
      counter.applyOperation(
        ObjectMessage(
          serial: '01',
          siteCode: 'site1',
          operation: ObjectOperation(
            action: ObjectOperationAction.counterInc,
            objectId: 'counter:abc@1000',
            counterOp: ObjectsCounterOp(amount: 30),
          ),
        ),
      );

      final update = counter.replaceData(
        ObjectState(
          objectId: 'counter:abc@1000',
          siteTimeserials: {'site1': '05'},
          tombstone: true,
        ),
        ObjectMessage(
          serial: '05',
          siteCode: 'site1',
          serialTimestamp: 3000,
        ),
      );

      expect(counter.isTombstone, isTrue);
      expect(counter.tombstonedAt, equals(3000));
      expect(counter.data, equals(0));
      expect(update.amount, equals(-30));
    });
  });

  group('RTLC7d3 - Unsupported action is ignored', () {
    test('returns null for an unsupported action like MAP_SET', () {
      final counter = LiveCounter(objectId: 'counter:abc@1000');

      final update = counter.applyOperation(
        ObjectMessage(
          serial: '01',
          siteCode: 'site1',
          operation: ObjectOperation(
            action: ObjectOperationAction.mapSet,
            objectId: 'counter:abc@1000',
          ),
        ),
      );

      expect(update, isNull);
      expect(counter.data, equals(0));
    });
  });

  group('RTLC14 - Diff calculation', () {
    test('replaceData returns diff as newData minus previousData', () {
      final counter = LiveCounter(objectId: 'counter:abc@1000');

      // Set to 10
      counter.applyOperation(
        ObjectMessage(
          serial: '01',
          siteCode: 'site1',
          operation: ObjectOperation(
            action: ObjectOperationAction.counterInc,
            objectId: 'counter:abc@1000',
            counterOp: ObjectsCounterOp(amount: 10),
          ),
        ),
      );

      // Replace with 25 (diff should be 15)
      final update = counter.replaceData(
        ObjectState(
          objectId: 'counter:abc@1000',
          siteTimeserials: {'site1': '05'},
          counter: ObjectsCounter(count: 25),
        ),
        ObjectMessage(serial: '05', siteCode: 'site1'),
      );

      expect(update.amount, equals(15));
    });
  });
}
