import 'batch_context.dart';
import 'instance.dart';
import 'path_object.dart';

/// PathObject specialized for `LiveMap` access at a path.
///
/// Obtained via `PathObject.asLiveMap()`. Provides typed access to
/// map-specific navigation, read, and mutation operations.
///
/// Spec: PO3
abstract class LiveMapPathObject {
  /// The fully-qualified path string.
  String path();

  /// Navigate to a child by key. Returns a new [PathObject].
  ///
  /// Spec: PO3a
  PathObject get(String key);

  /// Navigate via dot-separated deep path. Returns a new [PathObject].
  ///
  /// Spec: PO3b
  PathObject at(String path);

  /// Returns key-[PathObject] pairs for all non-tombstoned entries.
  ///
  /// If the path does not resolve to a `LiveMap`, returns an empty iterable.
  ///
  /// Spec: PO3c
  Iterable<MapEntry<String, PathObject>> entries();

  /// Returns key strings for all non-tombstoned entries.
  ///
  /// If the path does not resolve to a `LiveMap`, returns an empty iterable.
  ///
  /// Spec: PO3d
  Iterable<String> keys();

  /// Returns child [PathObject]s for all non-tombstoned entries.
  ///
  /// If the path does not resolve to a `LiveMap`, returns an empty iterable.
  ///
  /// Spec: PO3e
  Iterable<PathObject> values();

  /// Returns the number of non-tombstoned entries.
  ///
  /// If the path does not resolve to a `LiveMap`, returns null.
  ///
  /// Spec: PO3f
  int? size();

  /// Sets a key to a value. Returns a Future completing on ACK/NACK.
  ///
  /// [value] may be a primitive (`String`, `num`, `bool`, `Uint8List`,
  /// `List`, `Map`), a [LiveMapValue], or a [LiveCounterValue] descriptor.
  /// Descriptors enable atomic creation of nested structures.
  ///
  /// Requires `OBJECT_PUBLISH` channel mode. Throws if the path does not
  /// resolve to a `LiveMap`.
  ///
  /// Spec: PO3g
  Future<void> set(String key, Object value);

  /// Removes a key. Returns a Future completing on ACK/NACK.
  ///
  /// Requires `OBJECT_PUBLISH` channel mode. Throws if the path does not
  /// resolve to a `LiveMap`.
  ///
  /// Spec: PO3h
  Future<void> remove(String key);

  /// Returns a [LiveMapInstance] if the path resolves to a `LiveMap`,
  /// or null otherwise.
  ///
  /// Spec: PO3i
  LiveMapInstance? instance();

  /// In-memory snapshot as a nested `Map`, or null if unresolvable.
  ///
  /// Spec: PO3j
  Map<String, Object?>? compact();

  /// JSON-serializable snapshot as a `Map`, or null if unresolvable.
  ///
  /// Spec: PO3k
  Map<String, Object?>? compactJson();

  /// Groups operations into a single channel message.
  ///
  /// Spec: PO3l
  Future<void> batch(void Function(LiveMapBatchContext) fn);
}
