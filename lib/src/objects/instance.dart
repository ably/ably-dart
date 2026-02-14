import 'batch_context.dart';
import 'events.dart';
import 'subscription.dart';

/// An `Instance` wraps a specific `LiveObject` bound to an `objectId`.
///
/// Unlike [PathObject], an `Instance` tracks a specific object. If the object
/// at a path is replaced, an `Instance` obtained before the replacement still
/// refers to the original object.
///
/// Spec: PO6
abstract class Instance {
  /// The `objectId` of the underlying `LiveObject`.
  ///
  /// Returns null for primitive instances.
  ///
  /// Spec: PO6b
  String? get id;

  /// Registers an instance-based subscription.
  ///
  /// The subscription follows this specific object instance, not a path.
  /// If the instance is tombstoned, the listener fires with a final event
  /// and the subscription is automatically deregistered.
  ///
  /// Spec: PO6c
  Subscription subscribe(void Function(InstanceSubscriptionEvent) listener);

  /// Reads the current value.
  Object? value();

  /// In-memory snapshot.
  Object? compact();

  /// JSON-serializable snapshot.
  Object? compactJson();
}

/// Instance of a `LiveMap` object.
///
/// Spec: PO6d
abstract class LiveMapInstance extends Instance {
  /// Returns a child [Instance] for the entry at [key], or null if the
  /// key does not exist or is tombstoned.
  ///
  /// Spec: PO6d1
  Instance? get(String key);

  /// Returns key-[Instance] pairs for all non-tombstoned entries.
  ///
  /// Spec: PO6d2
  Iterable<MapEntry<String, Instance>> entries();

  /// Returns keys for all non-tombstoned entries.
  ///
  /// Spec: PO6d2
  Iterable<String> keys();

  /// Returns child [Instance] values for all non-tombstoned entries.
  ///
  /// Spec: PO6d2
  Iterable<Instance> values();

  /// Returns the number of non-tombstoned entries, or null.
  ///
  /// Spec: PO6d2
  int? size();

  /// Sets a key to a value on this map instance.
  ///
  /// Spec: PO6d3
  Future<void> set(String key, Object value);

  /// Removes a key from this map instance.
  ///
  /// Spec: PO6d3
  Future<void> remove(String key);

  /// Clears all entries from this map instance.
  ///
  /// Spec: PO6d3
  Future<void> clear();

  @override
  Map<String, Object?>? compact();

  @override
  Map<String, Object?>? compactJson();

  /// Groups operations into a single channel message.
  ///
  /// Spec: PO6d5
  Future<void> batch(void Function(LiveMapBatchContext) fn);
}

/// Instance of a `LiveCounter` object.
///
/// Spec: PO6e
abstract class LiveCounterInstance extends Instance {
  /// Returns the current counter value.
  ///
  /// Spec: PO6e1
  @override
  num? value();

  /// Sends a `COUNTER_INC` operation. [amount] defaults to 1.
  ///
  /// Spec: PO6e2
  Future<void> increment([num amount = 1]);

  /// Alias for `increment(-amount)`. [amount] defaults to 1.
  ///
  /// Spec: PO6e2
  Future<void> decrement([num amount = 1]);

  @override
  num? compact();

  @override
  num? compactJson();

  /// Groups operations into a single channel message.
  ///
  /// Spec: PO6e4
  Future<void> batch(void Function(LiveCounterBatchContext) fn);
}

/// Instance for a primitive value.
///
/// A snapshot of the primitive value at the time of retrieval.
/// Primitive instances are read-only.
///
/// Spec: PO6f
abstract class PrimitiveInstance extends Instance {
  /// Returns the primitive value.
  ///
  /// Spec: PO6f2
  @override
  Object? value();

  @override
  Object? compact();

  @override
  Object? compactJson();
}
