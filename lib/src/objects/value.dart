/// Descriptor for creating a new `LiveMap` via `set()`.
///
/// This is not a live object — it is a lightweight descriptor that is passed
/// to `LiveMapPathObject.set()` or `LiveMapInstance.set()` to atomically
/// create a new `LiveMap`. Nested descriptors in [entries] enable atomic
/// deep creation of entire subtrees in a single operation.
///
/// Spec: PO7a
class LiveMapValue {
  /// Creates a descriptor for a new `LiveMap`.
  ///
  /// [entries] is an optional map of initial entries. Values may be
  /// primitives (`String`, `num`, `bool`, `Uint8List`, `List`, `Map`),
  /// or other descriptors (`LiveMapValue`, `LiveCounterValue`) for
  /// atomic nested creation.
  ///
  /// Validation of entries is deferred to the `set()` call.
  ///
  /// Spec: PO7a1, PO7a2, PO7a3, PO7a4
  LiveMapValue.create([Map<String, Object>? entries]) : _entries = entries;

  final Map<String, Object>? _entries;

  /// The initial entries, or null if none were provided.
  Map<String, Object>? get entries => _entries;
}

/// Descriptor for creating a new `LiveCounter` via `set()`.
///
/// This is not a live object — it is a lightweight descriptor that is passed
/// to `LiveMapPathObject.set()` or `LiveMapInstance.set()` to atomically
/// create a new `LiveCounter`.
///
/// Spec: PO7b
class LiveCounterValue {
  /// Creates a descriptor for a new `LiveCounter`.
  ///
  /// [count] is the initial counter value, defaulting to 0.
  /// Validation of the count value is deferred to the `set()` call.
  ///
  /// Spec: PO7b1, PO7b2, PO7b3
  LiveCounterValue.create([num count = 0]) : _count = count;

  final num _count;

  /// The initial counter value.
  num get count => _count;
}
