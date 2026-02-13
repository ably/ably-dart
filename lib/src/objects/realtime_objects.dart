import 'path_object.dart';

/// Sync state events for the objects on a channel.
///
/// Spec: PO1c1
enum ObjectsEvent {
  /// The local copy of objects is being synchronised with the Ably service.
  syncing,

  /// The local copy of objects has been synchronised with the Ably service.
  synced,
}

/// Subscription handle for sync state events, returned by
/// [RealtimeObjects.on].
///
/// Spec: PO1c2
abstract class StatusSubscription {
  /// Deregisters the listener.
  void off();
}

/// Entry point for path-based object access on a channel.
///
/// Accessed via `channel.objects`. Provides the [get] method to obtain
/// a [PathObject] for the root of the object graph, and [on]/[off] methods
/// to listen for sync state transitions.
///
/// Spec: PO1
abstract class RealtimeObjects {
  /// Returns a [PathObject] for the root of the object graph.
  ///
  /// Requires `OBJECT_SUBSCRIBE` channel mode. Implicitly attaches to the
  /// channel if not already attached. Waits for the sync state to reach
  /// `SYNCED` before returning.
  ///
  /// Spec: PO1b
  Future<PathObject> get();

  /// Registers a listener for sync state events.
  ///
  /// Returns a [StatusSubscription] whose [StatusSubscription.off] method
  /// deregisters the listener.
  ///
  /// Spec: PO1c
  StatusSubscription on(ObjectsEvent event, void Function() callback);

  /// Deregisters a sync state event listener.
  ///
  /// Spec: PO1d
  void off(ObjectsEvent event, void Function() callback);
}
