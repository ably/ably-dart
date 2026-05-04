/// Details of a push subscription to a channel.
///
/// Exactly one of [deviceId] or [clientId] must be non-null when creating
/// a subscription. Use the named constructors [forDevice] and [forClientId]
/// to enforce this at construction time.
///
/// Spec: PCS1–PCS5
class PushChannelSubscription {
  /// Creates a PushChannelSubscription.
  ///
  /// This general constructor does not enforce the PCS5 constraint
  /// (exactly one of deviceId/clientId). Use [forDevice] or [forClientId]
  /// for compile-time safety, or this constructor when deserializing.
  PushChannelSubscription({
    required this.channel,
    this.deviceId,
    this.clientId,
  });

  /// Creates a device-based channel subscription.
  ///
  /// Spec: PCS5
  PushChannelSubscription.forDevice({
    required this.channel,
    required String this.deviceId,
  }) : clientId = null;

  /// Creates a clientId-based channel subscription.
  ///
  /// Spec: PCS5
  PushChannelSubscription.forClientId({
    required this.channel,
    required String this.clientId,
  }) : deviceId = null;

  /// Creates a PushChannelSubscription from a JSON map.
  factory PushChannelSubscription.fromMap(Map<String, dynamic> map) {
    return PushChannelSubscription(
      channel: map['channel'] as String,
      deviceId: map['deviceId'] as String?,
      clientId: map['clientId'] as String?,
    );
  }

  /// The channel name associated with this subscription.
  ///
  /// Spec: PCS4
  final String channel;

  /// The deviceId for device-based subscriptions.
  ///
  /// Spec: PCS2
  final String? deviceId;

  /// The clientId for client-based subscriptions.
  ///
  /// Spec: PCS3
  final String? clientId;

  /// Serializes to a JSON map, omitting null fields.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'channel': channel,
    };
    if (deviceId != null) map['deviceId'] = deviceId;
    if (clientId != null) map['clientId'] = clientId;
    return map;
  }
}
