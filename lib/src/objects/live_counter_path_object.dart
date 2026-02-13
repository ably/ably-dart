import 'batch_context.dart';
import 'instance.dart';

/// PathObject specialized for `LiveCounter` access at a path.
///
/// Obtained via `PathObject.asCounter()`. Provides typed access to
/// counter-specific read and mutation operations.
///
/// Spec: PO4
abstract class LiveCounterPathObject {
  /// The fully-qualified path string.
  String path();

  /// Returns the current counter value, or null if the path does not
  /// resolve to a `LiveCounter`.
  ///
  /// Spec: PO4a
  num? value();

  /// Sends a `COUNTER_INC` operation. [amount] defaults to 1.
  ///
  /// Requires `OBJECT_PUBLISH` channel mode. Throws if the path does not
  /// resolve to a `LiveCounter`.
  ///
  /// Spec: PO4b
  Future<void> increment([num amount = 1]);

  /// Alias for `increment(-amount)`. [amount] defaults to 1.
  ///
  /// Spec: PO4c
  Future<void> decrement([num amount = 1]);

  /// Returns a [LiveCounterInstance] if the path resolves to a
  /// `LiveCounter`, or null otherwise.
  ///
  /// Spec: PO4d
  LiveCounterInstance? instance();

  /// Snapshot as `num?` (alias for [value]).
  ///
  /// Spec: PO4e
  num? compact();

  /// JSON-serializable snapshot as `num?` (alias for [value]).
  ///
  /// Spec: PO4f
  num? compactJson();

  /// Groups operations into a single channel message.
  ///
  /// Spec: PO4g
  Future<void> batch(void Function(LiveCounterBatchContext) fn);
}
