import 'push_admin.dart';

/// The Push object provides access to push notification administration.
///
/// Spec: RSH1
abstract class Push {
  /// The PushAdmin interface for managing push notifications.
  ///
  /// Spec: RSH1
  PushAdmin get admin;
}
