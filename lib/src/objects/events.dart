import 'instance.dart';
import 'path_object.dart';

/// Event delivered to path-based subscription listeners.
///
/// Spec: PO10a
class PathObjectSubscriptionEvent {
  /// Creates a [PathObjectSubscriptionEvent].
  const PathObjectSubscriptionEvent({
    required this.pathObject,
    this.message,
  });

  /// The [PathObject] representing the path where the change occurred.
  ///
  /// Spec: PO10a1
  final PathObject pathObject;

  /// The ObjectMessage that caused the change, if applicable.
  ///
  /// Spec: PO10a2
  final Object? message;
}

/// Event delivered to instance-based subscription listeners.
///
/// Spec: PO10b
class InstanceSubscriptionEvent {
  /// Creates an [InstanceSubscriptionEvent].
  const InstanceSubscriptionEvent({
    required this.instance,
    this.message,
  });

  /// The [Instance] representing the updated object.
  ///
  /// Spec: PO10b1
  final Instance instance;

  /// The ObjectMessage that caused the change, if applicable.
  ///
  /// Spec: PO10b2
  final Object? message;
}

/// Represents a cyclic reference in `compactJson()` output.
///
/// When `compactJson()` encounters a `LiveMap` entry that refers to an
/// ancestor in the object graph, it emits an [ObjectIdReference] instead
/// of recursing infinitely.
///
/// Spec: PO10c
class ObjectIdReference {
  /// Creates an [ObjectIdReference].
  const ObjectIdReference({required this.objectId});

  /// The `objectId` of the referenced object.
  ///
  /// Spec: PO10c1
  final String objectId;

  /// Converts to a JSON-serializable map.
  Map<String, String> toJson() => {'objectId': objectId};
}
