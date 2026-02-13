/// Base batch context providing read operations during a `batch()` call.
///
/// Spec: PO9b
abstract class BatchContext {
  /// The `objectId` of the underlying instance, or null for primitives.
  String? get id;

  /// Reads the current value (from pre-batch state).
  Object? value();

  /// In-memory snapshot (from pre-batch state).
  Object? compact();

  /// JSON-serializable snapshot (from pre-batch state).
  Object? compactJson();
}

/// Batch context for `LiveMap` operations.
///
/// Provides synchronous mutation methods that queue operations to be sent
/// as a single channel message when the batch function returns.
///
/// Spec: PO9c
abstract class LiveMapBatchContext extends BatchContext {
  /// Queues a `MAP_SET` operation.
  ///
  /// Spec: PO9c1
  void set(String key, Object value);

  /// Queues a `MAP_REMOVE` operation.
  ///
  /// Spec: PO9c2
  void remove(String key);

  /// Returns a child [BatchContext] for the entry at [key], or null.
  ///
  /// Spec: PO9c3
  BatchContext? get(String key);

  /// Returns key-[BatchContext] pairs for all non-tombstoned entries.
  ///
  /// Spec: PO9c3
  Iterable<MapEntry<String, BatchContext>> entries();

  /// Returns keys for all non-tombstoned entries.
  ///
  /// Spec: PO9c3
  Iterable<String> keys();

  /// Returns [BatchContext] values for all non-tombstoned entries.
  ///
  /// Spec: PO9c3
  Iterable<BatchContext> values();

  /// Returns the number of non-tombstoned entries, or null.
  ///
  /// Spec: PO9c3
  int? size();

  @override
  Map<String, Object?>? compact();

  @override
  Map<String, Object?>? compactJson();
}

/// Batch context for `LiveCounter` operations.
///
/// Provides synchronous mutation methods that queue operations to be sent
/// as a single channel message when the batch function returns.
///
/// Spec: PO9d
abstract class LiveCounterBatchContext extends BatchContext {
  /// Queues a `COUNTER_INC` operation.
  ///
  /// Spec: PO9d1
  void increment([num amount = 1]);

  /// Queues a `COUNTER_INC` operation with negated amount.
  ///
  /// Spec: PO9d2
  void decrement([num amount = 1]);

  @override
  num? value();

  @override
  num? compact();

  @override
  num? compactJson();
}
