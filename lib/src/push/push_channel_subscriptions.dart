import '../pagination/paginated_result.dart';
import 'push_channel_subscription.dart';

/// Admin interface for managing push channel subscriptions.
///
/// Spec: RSH1c
abstract class PushChannelSubscriptions {
  /// Lists channel subscriptions filtered by the provided params.
  ///
  /// Supported params include `channel`, `deviceId`, `clientId`, and `limit`.
  ///
  /// Spec: RSH1c1
  Future<PaginatedResult<PushChannelSubscription>> list(
    Map<String, String> params,
  );

  /// Lists channels with active push subscriptions.
  ///
  /// Returns a paginated result of channel name strings.
  ///
  /// Spec: RSH1c2
  Future<PaginatedResult<String>> listChannels(Map<String, String> params);

  /// Saves (creates or updates) a channel subscription.
  ///
  /// Spec: RSH1c3
  Future<PushChannelSubscription> save(PushChannelSubscription subscription);

  /// Removes a channel subscription.
  ///
  /// The subscription's attributes are sent as query parameters.
  /// Succeeds even if the subscription does not exist.
  ///
  /// Spec: RSH1c4
  Future<void> remove(PushChannelSubscription subscription);

  /// Removes channel subscriptions matching the provided params.
  ///
  /// Supported params include `clientId` and `deviceId`.
  /// Succeeds even if no subscriptions match.
  ///
  /// Spec: RSH1c5
  Future<void> removeWhere(Map<String, String> params);
}
