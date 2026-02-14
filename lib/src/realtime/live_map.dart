import 'package:meta/meta.dart';

import 'live_object.dart';
import 'object_message.dart';

/// Update event for a LiveMap.
///
/// Spec: RTLM18
class LiveMapUpdate extends LiveObjectUpdate {
  LiveMapUpdate({required this.update, super.noop});

  /// Creates a noop update.
  LiveMapUpdate.noop()
      : update = {},
        super(noop: true);

  /// Map of keys that were updated or removed.
  ///
  /// Spec: RTLM18b
  final Map<String, String> update;
}

/// A CRDT LWW (Last-Write-Wins) map.
///
/// Holds a `Dict<String, ObjectsMapEntry>` as its data and supports
/// MAP_SET, MAP_REMOVE, MAP_CREATE operations, data replacement during
/// sync, entry-level and object-level tombstoning, and LWW serial comparison.
///
/// Spec: RTLM1, RTLM2, RTLM3
class LiveMap extends LiveObject {
  /// Creates a zero-value LiveMap.
  ///
  /// Spec: RTLM4
  LiveMap({required super.objectId})
      : _data = {},
        _clearSerial = '';

  /// The internal map data.
  ///
  /// Spec: RTLM3
  Map<String, ObjectsMapEntry> _data;

  /// The timeserial of the most recent MAP_CLEAR operation.
  ///
  /// Spec: RTLM24
  String _clearSerial;

  /// Exposed for testing only.
  @visibleForTesting
  String get clearSerial => _clearSerial;

  /// Returns the raw entry at [key], or null.
  /// Exposed for testing only.
  @visibleForTesting
  ObjectsMapEntry? getEntry(String key) => _data[key];

  /// Returns the number of non-tombstoned entries.
  ///
  /// Spec: RTLM10
  int size() {
    var count = 0;
    for (final entry in _data.values) {
      if (!entry.tombstone) {
        count++;
      }
    }
    return count;
  }

  /// Returns keys of non-tombstoned entries.
  ///
  /// Spec: RTLM12
  Iterable<String> keys() {
    return _data.entries.where((e) => !e.value.tombstone).map((e) => e.key);
  }

  /// Apply an ObjectOperation from an ObjectMessage.
  ///
  /// Returns a [LiveMapUpdate] if the operation was applied, or null
  /// if the operation was rejected.
  ///
  /// Spec: RTLM15
  @override
  LiveMapUpdate? applyOperation(ObjectMessage message) {
    // RTLM15b: Check if operation can be applied based on serial
    if (!canApplyOperation(message)) {
      return null;
    }

    // RTLM15c: Update siteTimeserials
    siteTimeserials[message.siteCode] = message.serial;

    // RTLM15e: If tombstoned, cannot apply
    if (isTombstone) {
      return null;
    }

    final operation = message.operation;
    if (operation == null) return null;

    switch (operation.action) {
      // RTLM15d1: MAP_CREATE
      case ObjectOperationAction.mapCreate:
        return _applyMapCreate(operation);

      // RTLM15d2: MAP_SET
      case ObjectOperationAction.mapSet:
        if (operation.mapOp == null) return null;
        return _applyMapSet(operation.mapOp!, message.serial);

      // RTLM15d3: MAP_REMOVE
      case ObjectOperationAction.mapRemove:
        if (operation.mapOp == null) return null;
        return _applyMapRemove(
          operation.mapOp!,
          message.serial,
          message.serialTimestamp,
        );

      // RTLM15d5: OBJECT_DELETE
      case ObjectOperationAction.objectDelete:
        final removedKeys = <String, String>{};
        for (final key in _data.keys) {
          if (!_data[key]!.tombstone) {
            removedKeys[key] = 'removed';
          }
        }
        tombstone(message);
        return LiveMapUpdate(update: removedKeys);

      // RTLM15d6: MAP_CLEAR
      case ObjectOperationAction.mapClear:
        return _applyMapClear(message.serial);

      // RTLM15d4: Unsupported action
      default:
        return null;
    }
  }

  /// Apply a MAP_CREATE operation.
  ///
  /// Spec: RTLM16
  LiveMapUpdate _applyMapCreate(ObjectOperation operation) {
    // RTLM16b: If already merged, noop
    if (createOperationIsMerged) {
      return LiveMapUpdate.noop();
    }

    // RTLM16d: Merge initial value
    return _mergeInitialValue(operation);
  }

  /// Apply a MAP_SET operation for a key.
  ///
  /// Spec: RTLM7
  LiveMapUpdate _applyMapSet(ObjectsMapOp mapOp, String serial) {
    // RTLM9f: Reject if serial <= clearSerial
    if (_clearSerial.isNotEmpty &&
        (serial.isEmpty || serial.compareTo(_clearSerial) <= 0)) {
      return LiveMapUpdate.noop();
    }

    final key = mapOp.key;
    final existing = _data[key];

    if (existing != null) {
      // RTLM7a1: Check LWW — if can't apply, noop
      if (!_canApplyMapOperation(existing.timeserial, serial)) {
        return LiveMapUpdate.noop();
      }

      // RTLM7a2: Apply to existing entry
      existing
        ..data = mapOp.data
        ..timeserial = serial
        ..tombstone = false
        ..tombstonedAt = null;
    } else {
      // RTLM7b: Create new entry
      _data[key] = ObjectsMapEntry(
        data: mapOp.data,
        timeserial: serial,
      );
    }

    // RTLM7f: Return update
    return LiveMapUpdate(update: {key: 'updated'});
  }

  /// Apply a MAP_REMOVE operation for a key.
  ///
  /// Spec: RTLM8
  LiveMapUpdate _applyMapRemove(
    ObjectsMapOp mapOp,
    String serial,
    int? serialTimestamp,
  ) {
    // RTLM9f: Reject if serial <= clearSerial
    if (_clearSerial.isNotEmpty &&
        (serial.isEmpty || serial.compareTo(_clearSerial) <= 0)) {
      return LiveMapUpdate.noop();
    }

    final key = mapOp.key;
    final existing = _data[key];
    final ts = serialTimestamp ?? DateTime.now().millisecondsSinceEpoch;

    if (existing != null) {
      // RTLM8a1: Check LWW
      if (!_canApplyMapOperation(existing.timeserial, serial)) {
        return LiveMapUpdate.noop();
      }

      // RTLM8a2: Tombstone existing entry
      existing
        ..data = null
        ..timeserial = serial
        ..tombstone = true
        ..tombstonedAt = ts;
    } else {
      // RTLM8b: Create tombstoned entry
      _data[key] = ObjectsMapEntry(
        timeserial: serial,
        tombstone: true,
        tombstonedAt: ts,
      );
    }

    // RTLM8e: Return update
    return LiveMapUpdate(update: {key: 'removed'});
  }

  /// Apply a MAP_CLEAR operation.
  ///
  /// Removes all entries whose timeserial is <= the clear serial.
  /// Entries with newer timeserials are preserved.
  ///
  /// Spec: RTLM25
  LiveMapUpdate _applyMapClear(String serial) {
    // RTLM25b: If not newer than current clearSerial, noop
    if (_clearSerial.isNotEmpty && serial.compareTo(_clearSerial) <= 0) {
      return LiveMapUpdate.noop();
    }

    // RTLM25c: Update clearSerial
    _clearSerial = serial;

    // RTLM25d: Remove entries with timeserial <= serial.
    // No need to tombstone — the clearSerial floor check (RTLM9f)
    // will reject any stale operations for these keys.
    final removedKeys = <String, String>{};
    _data.removeWhere((key, entry) {
      if (!entry.tombstone) {
        final entrySerial = entry.timeserial ?? '';
        if (entrySerial.isEmpty || entrySerial.compareTo(serial) <= 0) {
          removedKeys[key] = 'removed';
          return true;
        }
      }
      return false;
    });

    // RTLM25f: Return update with removed keys
    return LiveMapUpdate(update: removedKeys);
  }

  /// Determines whether a map operation can be applied to an entry
  /// based on LWW serial comparison.
  ///
  /// Spec: RTLM9
  bool _canApplyMapOperation(String? entrySerial, String? opSerial) {
    final entryExists = entrySerial != null && entrySerial.isNotEmpty;
    final opExists = opSerial != null && opSerial.isNotEmpty;

    // RTLM9b: Both empty/null → don't apply
    if (!entryExists && !opExists) return false;

    // RTLM9d: Only op exists → apply
    if (!entryExists) return true;

    // RTLM9c: Only entry exists → don't apply
    if (!opExists) return false;

    // RTLM9e: Both exist → lexicographic comparison
    return opSerial.compareTo(entrySerial) > 0;
  }

  /// Merge initial value from a create operation.
  ///
  /// Spec: RTLM17
  LiveMapUpdate _mergeInitialValue(ObjectOperation operation) {
    final mergedUpdate = <String, String>{};

    if (operation.map?.entries != null) {
      // RTLM17a: For each entry in the create operation
      for (final entry in operation.map!.entries.entries) {
        final key = entry.key;
        final mapEntry = entry.value;

        LiveMapUpdate result;
        if (mapEntry.tombstone) {
          // RTLM17a2: Tombstoned entry → apply as MAP_REMOVE
          result = _applyMapRemove(
            ObjectsMapOp(key: key),
            mapEntry.timeserial ?? '',
            mapEntry.tombstonedAt,
          );
        } else {
          // RTLM17a1: Non-tombstoned → apply as MAP_SET
          result = _applyMapSet(
            ObjectsMapOp(key: key, data: mapEntry.data),
            mapEntry.timeserial ?? '',
          );
        }

        // Merge results, skipping noops
        if (!result.noop) {
          mergedUpdate.addAll(result.update);
        }
      }
    }

    // RTLM17b: Set flag
    createOperationIsMerged = true;

    // RTLM17c: Return merged update
    return LiveMapUpdate(update: mergedUpdate);
  }

  /// Replace internal data from an ObjectState during sync.
  ///
  /// Spec: RTLM6
  LiveMapUpdate replaceData(
    ObjectState objectState,
    ObjectMessage outerMessage,
  ) {
    // RTLM6a: Replace siteTimeserials
    siteTimeserials
      ..clear()
      ..addAll(objectState.siteTimeserials);

    // RTLM6i: Restore clearSerial from sync state
    _clearSerial = objectState.clearSerial ?? '';

    // RTLM6e: If already tombstoned, noop
    if (isTombstone) {
      return LiveMapUpdate.noop();
    }

    // RTLM6f: If ObjectState says tombstone
    if (objectState.tombstone == true) {
      final removedKeys = <String, String>{};
      for (final key in _data.keys) {
        if (!_data[key]!.tombstone) {
          removedKeys[key] = 'removed';
        }
      }
      tombstone(outerMessage);
      return LiveMapUpdate(update: removedKeys);
    }

    // RTLM6g: Store previous data for diff
    final previousData = Map<String, ObjectsMapEntry>.from(_data);

    // RTLM6b: Reset createOperationIsMerged
    createOperationIsMerged = false;

    // RTLM6c: Set data from ObjectState.map.entries, or empty map
    _data = {};
    if (objectState.map?.entries != null) {
      for (final entry in objectState.map!.entries.entries) {
        final mapEntry = ObjectsMapEntry(
          data: entry.value.data,
          timeserial: entry.value.timeserial,
          tombstone: entry.value.tombstone,
          tombstonedAt: entry.value.tombstonedAt,
        );

        // RTLM6c1: For tombstoned entries, set tombstonedAt
        if (mapEntry.tombstone && mapEntry.tombstonedAt == null) {
          mapEntry.tombstonedAt = DateTime.now().millisecondsSinceEpoch;
        }

        _data[entry.key] = mapEntry;
      }
    }

    // RTLM6d: If createOp present, merge it
    if (objectState.createOp != null) {
      _mergeInitialValue(objectState.createOp!);
    }

    // RTLM6h, RTLM22: Calculate diff
    return _calculateDiff(previousData, _data);
  }

  /// Calculate diff between two data states.
  ///
  /// Spec: RTLM22
  LiveMapUpdate _calculateDiff(
    Map<String, ObjectsMapEntry> previousData,
    Map<String, ObjectsMapEntry> newData,
  ) {
    final update = <String, String>{};

    // Get non-tombstoned keys from previous
    final prevKeys = <String>{};
    for (final entry in previousData.entries) {
      if (!entry.value.tombstone) {
        prevKeys.add(entry.key);
      }
    }

    // Get non-tombstoned keys from new
    final newKeys = <String>{};
    for (final entry in newData.entries) {
      if (!entry.value.tombstone) {
        newKeys.add(entry.key);
      }
    }

    // RTLM22b1: Keys in previous but not new → removed
    for (final key in prevKeys) {
      if (!newKeys.contains(key)) {
        update[key] = 'removed';
      }
    }

    // RTLM22b2: Keys in new but not previous → updated
    for (final key in newKeys) {
      if (!prevKeys.contains(key)) {
        update[key] = 'updated';
      }
    }

    // RTLM22b3: Keys in both — compare data
    for (final key in prevKeys.intersection(newKeys)) {
      final prevEntry = previousData[key]!;
      final newEntry = newData[key]!;

      if (!_dataEquals(prevEntry.data, newEntry.data)) {
        update[key] = 'updated';
      }
    }

    return LiveMapUpdate(update: update);
  }

  /// Deep comparison of ObjectData values.
  bool _dataEquals(ObjectData? a, ObjectData? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.string == b.string &&
        a.number == b.number &&
        a.boolean == b.boolean &&
        a.objectId == b.objectId;
  }

  /// Garbage collect tombstoned entries past grace period.
  ///
  /// Spec: RTLM19
  void gcTombstonedEntries({
    required int currentTime,
    required int gracePeriod,
  }) {
    final keysToRemove = <String>[];
    for (final entry in _data.entries) {
      if (entry.value.tombstone &&
          entry.value.tombstonedAt != null &&
          (currentTime - entry.value.tombstonedAt!) >= gracePeriod) {
        keysToRemove.add(entry.key);
      }
    }
    for (final key in keysToRemove) {
      _data.remove(key);
    }
  }

  /// Set data to zero value (empty map).
  ///
  /// Spec: RTLM4, RTLM24b
  @override
  void setZeroValue() {
    _data = {};
    _clearSerial = '';
  }
}
