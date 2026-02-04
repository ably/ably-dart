/// Channel modes that define the capabilities requested for a channel.
///
/// Spec: TB2d
enum ChannelMode {
  /// Presence capability - allows presence operations.
  presence,

  /// Publish capability - allows publishing messages.
  publish,

  /// Subscribe capability - allows subscribing to messages.
  subscribe,

  /// Message subscribe capability - allows subscribing to messages only.
  messageSubscribe,

  /// Presence subscribe capability - allows subscribing to presence only.
  presenceSubscribe,

  /// Object subscribe capability - allows subscribing to objects.
  objectSubscribe,

  /// Object publish capability - allows publishing objects.
  objectPublish,
}
