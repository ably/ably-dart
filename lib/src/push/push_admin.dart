import 'push_channel_subscriptions.dart';
import 'push_device_registrations.dart';

/// The PushAdmin interface for administering push notifications.
///
/// Spec: RSH1
abstract class PushAdmin {
  /// Publishes a push notification to the given recipient.
  ///
  /// [recipient] identifies the target (e.g. clientId, deviceId, or
  /// transport-specific details). Must not be empty.
  /// [data] contains the notification payload (notification, data, etc.).
  /// Must not be empty.
  ///
  /// Spec: RSH1a
  Future<void> publish(
    Map<String, dynamic> recipient,
    Map<String, dynamic> data,
  );

  /// Access to the device registrations admin interface.
  ///
  /// Spec: RSH1b
  PushDeviceRegistrations get deviceRegistrations;

  /// Access to the channel subscriptions admin interface.
  ///
  /// Spec: RSH1c
  PushChannelSubscriptions get channelSubscriptions;
}
