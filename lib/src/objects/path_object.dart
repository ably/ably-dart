import 'batch_context.dart';
import 'events.dart';
import 'instance.dart';
import 'live_counter_path_object.dart';
import 'live_map_path_object.dart';
import 'primitive_path_object.dart';
import 'subscription.dart';
import 'subscription_options.dart';

/// A lightweight, deferred reference to a location in the object graph.
///
/// Construction is cheap — a [PathObject] stores path segments without
/// performing any I/O or object resolution. Resolution occurs lazily when
/// a method requiring the actual value is called (`value()`, `compact()`,
/// `set()`, etc.).
///
/// For type-safe access to type-specific operations, use the assertion
/// methods: [asLiveMap], [asCounter], [asString], [asNumber], [asBoolean],
/// [asBinary].
///
/// Spec: PO2
abstract class PathObject {
  /// Returns the fully-qualified path string.
  ///
  /// Segments are joined with `.` as separator. Segments containing literal
  /// dots are escaped with `\`. The root PathObject has an empty path `""`.
  ///
  /// Spec: PO2b
  String path();

  /// Navigates to a child by key. Returns a new [PathObject].
  ///
  /// No resolution or I/O occurs — this is a pure path construction
  /// operation.
  ///
  /// Spec: PO2c
  PathObject get(String key);

  /// Navigates via a dot-separated deep path. Returns a new [PathObject].
  ///
  /// Splits [path] on unescaped dots and appends all resulting segments.
  /// Escaped dots (`\.`) are treated as literal dots within a segment.
  /// No resolution or I/O occurs.
  ///
  /// Spec: PO2d
  PathObject at(String path);

  /// Reads the resolved value at this path.
  ///
  /// - LiveCounter: returns the numeric value
  /// - Primitive (string, number, boolean, binary): returns the value
  /// - LiveMap: returns null (use [compact] for map snapshots)
  /// - Unresolvable: returns null
  ///
  /// Spec: PO2e
  Object? value();

  /// Returns the [Instance] at this path.
  ///
  /// If the resolved value is a `LiveObject` (`LiveMap` or `LiveCounter`),
  /// returns an [Instance] wrapper. Returns null for primitives, tombstoned
  /// objects, or if the path is unresolvable.
  ///
  /// Spec: PO2f
  Instance? instance();

  /// Registers a path-based subscription.
  ///
  /// The subscription follows the *path*, not a specific object instance.
  /// If the object at this path is replaced, the subscription automatically
  /// observes the new object. Does not require the path to currently
  /// resolve — the subscription will fire when a value first appears.
  ///
  /// By default observes changes at any depth. Use [options] to limit
  /// observation depth.
  ///
  /// Spec: PO2g
  Subscription subscribe(
    void Function(PathObjectSubscriptionEvent) listener, {
    PathObjectSubscriptionOptions? options,
  });

  /// Returns an in-memory snapshot of the subtree at this path.
  ///
  /// - LiveMap: nested `Map<String, Object?>`
  /// - LiveCounter: `num`
  /// - Primitive: the value itself
  /// - Cyclic references produce shared object references
  /// - Unresolvable: null
  ///
  /// Spec: PO2h
  Object? compact();

  /// Returns a JSON-serializable snapshot of the subtree at this path.
  ///
  /// Same as [compact] except: binary values are base64-encoded strings,
  /// and cyclic references are represented as [ObjectIdReference] objects.
  ///
  /// Spec: PO2i
  Object? compactJson();

  /// Returns a [LiveMapPathObject] view of this path.
  ///
  /// If the path currently resolves and the value is not a `LiveMap`,
  /// throws an error. If the path does not resolve, returns the wrapper
  /// without throwing (resolution is deferred).
  ///
  /// Spec: PO2j1
  LiveMapPathObject asLiveMap();

  /// Returns a [LiveCounterPathObject] view of this path.
  ///
  /// Same resolution semantics as [asLiveMap] but for `LiveCounter`.
  ///
  /// Spec: PO2j2
  LiveCounterPathObject asCounter();

  /// Returns a [StringPathObject] view of this path.
  ///
  /// Spec: PO2j3
  StringPathObject asString();

  /// Returns a [NumberPathObject] view of this path.
  ///
  /// Spec: PO2j4
  NumberPathObject asNumber();

  /// Returns a [BooleanPathObject] view of this path.
  ///
  /// Spec: PO2j5
  BooleanPathObject asBoolean();

  /// Returns a [BinaryPathObject] view of this path.
  ///
  /// Spec: PO2j6
  BinaryPathObject asBinary();

  /// Groups operations into a single channel message.
  ///
  /// The [fn] function receives a [BatchContext] for the resolved object
  /// and must be synchronous. Operations are queued during execution and
  /// sent as a single `ProtocolMessage` when [fn] returns.
  ///
  /// Spec: PO2k, PO9
  Future<void> batch(void Function(BatchContext) fn);
}
