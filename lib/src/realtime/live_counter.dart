import 'live_object.dart';
import 'object_message.dart';

/// Update event for a LiveCounter.
///
/// Spec: RTLC11
class LiveCounterUpdate extends LiveObjectUpdate {
  LiveCounterUpdate({required this.amount, super.noop});

  /// Creates a noop update.
  LiveCounterUpdate.noop()
      : amount = 0,
        super(noop: true);

  /// The amount by which the counter was incremented or decremented.
  ///
  /// Spec: RTLC11b1
  final num amount;
}

/// A CRDT counter that holds a 64-bit floating-point number.
///
/// Supports increment operations, create operations (initial value merge),
/// data replacement during sync, tombstoning, and operation newness checks.
///
/// Spec: RTLC1, RTLC2, RTLC3
class LiveCounter extends LiveObject {
  /// Creates a zero-value LiveCounter.
  ///
  /// Spec: RTLC4
  LiveCounter({required super.objectId}) : _data = 0;

  /// The current counter value.
  ///
  /// Spec: RTLC3
  num _data;

  /// Public accessor for the counter value.
  ///
  /// Spec: RTLC5
  num get data => _data;

  /// Apply an ObjectOperation from an ObjectMessage.
  ///
  /// Returns a [LiveCounterUpdate] if the operation was applied, or null
  /// if the operation was rejected (stale serial, tombstoned, etc.).
  ///
  /// Spec: RTLC7
  @override
  LiveCounterUpdate? applyOperation(ObjectMessage message) {
    // RTLC7b: Check if operation can be applied based on serial
    if (!canApplyOperation(message)) {
      return null;
    }

    // RTLC7c: Update siteTimeserials
    siteTimeserials[message.siteCode] = message.serial;

    // RTLC7e: If tombstoned, cannot apply
    if (isTombstone) {
      return null;
    }

    final operation = message.operation;
    if (operation == null) return null;

    switch (operation.action) {
      // RTLC7d1: COUNTER_CREATE
      case ObjectOperationAction.counterCreate:
        final update = _applyCounterCreate(operation);
        return update;

      // RTLC7d2: COUNTER_INC
      case ObjectOperationAction.counterInc:
        final update = _applyCounterInc(operation.counterOp);
        return update;

      // RTLC7d4: OBJECT_DELETE
      case ObjectOperationAction.objectDelete:
        final previousData = _data;
        tombstone(message);
        return LiveCounterUpdate(amount: -previousData);

      // RTLC7d3: Unsupported action
      default:
        return null;
    }
  }

  /// Apply a COUNTER_CREATE operation.
  ///
  /// Spec: RTLC8
  LiveCounterUpdate _applyCounterCreate(ObjectOperation operation) {
    // RTLC8b: If already merged, noop
    if (createOperationIsMerged) {
      return LiveCounterUpdate.noop();
    }

    // RTLC8c: Merge initial value
    return _mergeInitialValue(operation);
  }

  /// Apply a COUNTER_INC operation.
  ///
  /// Spec: RTLC9
  LiveCounterUpdate _applyCounterInc(ObjectsCounterOp? counterOp) {
    final amount = counterOp?.amount;

    // RTLC9e: If amount doesn't exist, noop
    if (amount == null) {
      return LiveCounterUpdate.noop();
    }

    // RTLC9b: Add amount to data
    _data += amount;

    // RTLC9d: Return update with amount
    return LiveCounterUpdate(amount: amount);
  }

  /// Merge initial value from a create operation.
  ///
  /// Spec: RTLC10
  LiveCounterUpdate _mergeInitialValue(ObjectOperation operation) {
    final count = operation.counter?.count;

    // RTLC10b: Set flag
    createOperationIsMerged = true;

    // RTLC10a: Add count to data if it exists
    if (count != null) {
      _data += count;
      // RTLC10c: Return update with count
      return LiveCounterUpdate(amount: count);
    }

    // RTLC10d: No count, noop
    return LiveCounterUpdate.noop();
  }

  /// Replace internal data from an ObjectState during sync.
  ///
  /// Spec: RTLC6
  LiveCounterUpdate replaceData(
    ObjectState objectState,
    ObjectMessage outerMessage,
  ) {
    // RTLC6a: Replace siteTimeserials
    siteTimeserials
      ..clear()
      ..addAll(objectState.siteTimeserials);

    // RTLC6e: If already tombstoned, noop (but still update siteTimeserials)
    if (isTombstone) {
      return LiveCounterUpdate.noop();
    }

    // RTLC6f: If ObjectState says tombstone, tombstone this counter
    if (objectState.tombstone == true) {
      final previousData = _data;
      tombstone(outerMessage);
      return LiveCounterUpdate(amount: -previousData);
    }

    // RTLC6g: Store previous data for diff
    final previousData = _data;

    // RTLC6b: Reset createOperationIsMerged
    createOperationIsMerged = false;

    // RTLC6c: Set data from ObjectState.counter.count, or 0
    _data = objectState.counter?.count ?? 0;

    // RTLC6d: If createOp present, merge it
    if (objectState.createOp != null) {
      _mergeInitialValue(objectState.createOp!);
    }

    // RTLC6h, RTLC14: Calculate diff
    return LiveCounterUpdate(amount: _data - previousData);
  }

  /// Set data to zero value.
  ///
  /// Spec: RTLC4
  @override
  void setZeroValue() {
    _data = 0;
  }
}
