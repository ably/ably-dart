/// Actions for object operations.
///
/// Spec: OOP2
enum ObjectOperationAction {
  mapCreate,
  mapSet,
  mapRemove,
  counterCreate,
  counterInc,
  objectDelete,
  mapClear,
}

/// Wire protocol integer mapping for [ObjectOperationAction].
extension ObjectOperationActionExtension on ObjectOperationAction {
  static const Map<ObjectOperationAction, int> _toWire = {
    ObjectOperationAction.mapCreate: 0,
    ObjectOperationAction.mapSet: 1,
    ObjectOperationAction.mapRemove: 2,
    ObjectOperationAction.counterCreate: 3,
    ObjectOperationAction.counterInc: 4,
    ObjectOperationAction.objectDelete: 5,
    ObjectOperationAction.mapClear: 6,
  };

  static final Map<int, ObjectOperationAction> _fromWire = {
    for (final entry in _toWire.entries) entry.value: entry.key,
  };

  /// Converts to wire protocol integer.
  int toInt() => _toWire[this]!;

  /// Creates from wire protocol integer.
  static ObjectOperationAction? fromInt(int value) => _fromWire[value];

  /// Creates from string name.
  static ObjectOperationAction? fromString(String name) {
    switch (name) {
      case 'MAP_CREATE':
        return ObjectOperationAction.mapCreate;
      case 'MAP_SET':
        return ObjectOperationAction.mapSet;
      case 'MAP_REMOVE':
        return ObjectOperationAction.mapRemove;
      case 'COUNTER_CREATE':
        return ObjectOperationAction.counterCreate;
      case 'COUNTER_INC':
        return ObjectOperationAction.counterInc;
      case 'OBJECT_DELETE':
        return ObjectOperationAction.objectDelete;
      case 'MAP_CLEAR':
        return ObjectOperationAction.mapClear;
      default:
        return null;
    }
  }
}

/// Data stored in a map entry.
///
/// Exactly one field should be non-null.
class ObjectData {
  ObjectData({
    this.string,
    this.number,
    this.boolean,
    this.objectId,
    this.bytes,
    this.json,
  });

  final String? string;
  final num? number;
  final bool? boolean;
  final String? objectId;
  final List<int>? bytes;
  final Object? json;

  /// Deep equality check.
  bool deepEquals(ObjectData? other) {
    if (other == null) return false;
    return string == other.string &&
        number == other.number &&
        boolean == other.boolean &&
        objectId == other.objectId;
    // bytes and json comparison omitted for simplicity
  }
}

/// A map operation (MAP_SET or MAP_REMOVE payload).
class ObjectsMapOp {
  ObjectsMapOp({required this.key, this.data});

  final String key;
  final ObjectData? data;
}

/// A counter operation (COUNTER_INC payload).
class ObjectsCounterOp {
  ObjectsCounterOp({this.amount});

  final num? amount;
}

/// Initial map value for MAP_CREATE.
class ObjectsMap {
  ObjectsMap({this.semantics = 'LWW', Map<String, ObjectsMapEntry>? entries})
      : entries = entries ?? {};

  final String semantics;
  final Map<String, ObjectsMapEntry> entries;
}

/// Initial counter value for COUNTER_CREATE.
class ObjectsCounter {
  ObjectsCounter({this.count});

  final num? count;
}

/// A single entry in a LiveMap's data.
///
/// Spec: RTLM3, OME2
class ObjectsMapEntry {
  ObjectsMapEntry({
    this.data,
    this.timeserial,
    this.tombstone = false,
    this.tombstonedAt,
  });

  ObjectData? data;
  String? timeserial;
  bool tombstone;
  int? tombstonedAt;
}

/// An operation within an ObjectMessage.
///
/// Spec: OOP1, OOP3
class ObjectOperation {
  ObjectOperation({
    required this.action,
    required this.objectId,
    this.mapOp,
    this.counterOp,
    this.map,
    this.counter,
    this.nonce,
    this.initialValue,
  });

  final ObjectOperationAction action;
  final String objectId;
  final ObjectsMapOp? mapOp;
  final ObjectsCounterOp? counterOp;
  final ObjectsMap? map;
  final ObjectsCounter? counter;
  final String? nonce;
  final String? initialValue;
}

/// A message describing an operation on an object.
///
/// Spec: OM2
class ObjectMessage {
  ObjectMessage({
    required this.serial,
    required this.siteCode,
    this.serialTimestamp,
    this.operation,
  });

  final String serial;
  final String siteCode;
  final int? serialTimestamp;
  final ObjectOperation? operation;
}

/// Server-provided state of an object during sync.
class ObjectState {
  ObjectState({
    required this.objectId,
    this.siteTimeserials = const {},
    this.tombstone,
    this.counter,
    this.map,
    this.createOp,
    this.clearSerial,
  });

  final String objectId;
  final Map<String, String> siteTimeserials;
  final bool? tombstone;
  final ObjectsCounter? counter;
  final ObjectsMap? map;
  final ObjectOperation? createOp;

  /// The timeserial of the most recent MAP_CLEAR operation.
  ///
  /// Spec: RTLM24
  final String? clearSerial;
}
