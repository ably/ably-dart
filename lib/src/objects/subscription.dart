/// A handle returned by `subscribe()` methods on `PathObject` and `Instance`.
///
/// Spec: PO11
abstract class Subscription {
  /// Deregisters the listener that was registered when this subscription
  /// was created. Calling this more than once has no effect.
  ///
  /// Spec: PO11a, PO11b
  void unsubscribe();
}
