/// Options for configuring path-based subscriptions.
///
/// Spec: PO8
class PathObjectSubscriptionOptions {
  /// Creates subscription options.
  ///
  /// [depth] controls the depth of nested change observation.
  const PathObjectSubscriptionOptions({this.depth});

  /// The depth of nested change observation.
  ///
  /// - If null or omitted, the subscription observes changes at any depth
  ///   below the subscribed path (unlimited).
  /// - If set to 1, only direct changes to the object at the subscribed path
  ///   are observed.
  /// - If set to a value greater than 1, changes up to that many levels deep
  ///   are observed.
  /// - The minimum permitted value is 1.
  ///
  /// Spec: PO8a
  final int? depth;
}
