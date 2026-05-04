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

  /// Annotation publish capability - allows publishing annotations.
  annotationPublish,

  /// Annotation subscribe capability - allows subscribing to annotations.
  annotationSubscribe,
}

/// Protocol message flag bit constants per spec TR3.
/// Flag n means bit value = 2^n.
const int flagHasPresence = 1 << 0; // TR3a
const int flagHasBacklog = 1 << 1; // TR3b
const int flagResumed = 1 << 2; // TR3c
const int flagTransient = 1 << 4; // TR3e
const int flagAttachResume = 1 << 5; // TR3f

/// Extension providing flag bit encoding/decoding for ChannelMode.
///
/// Spec: TR3
extension ChannelModeFlags on ChannelMode {
  /// Returns the flag bit value for this mode per TR3.
  int get flagBit {
    switch (this) {
      case ChannelMode.presence:
        return 1 << 16; // 65536   TR3q
      case ChannelMode.publish:
        return 1 << 17; // 131072  TR3r
      case ChannelMode.subscribe:
        return 1 << 18; // 262144  TR3s
      case ChannelMode.messageSubscribe:
        return 1 << 18; // 262144  TR3u (synonym for subscribe)
      case ChannelMode.presenceSubscribe:
        return 1 << 19; // 524288  TR3t
      case ChannelMode.objectSubscribe:
        return 1 << 24; // TR3y
      case ChannelMode.objectPublish:
        return 1 << 25; // TR3z
      case ChannelMode.annotationPublish:
        return 1 << 21; // TR3w - flag 21
      case ChannelMode.annotationSubscribe:
        return 1 << 22; // TR3x - flag 22
    }
  }
}

/// Encodes a list of ChannelModes into a flags integer.
int encodeModeFlags(List<ChannelMode> modes) {
  var flags = 0;
  for (final mode in modes) {
    flags |= mode.flagBit;
  }
  return flags;
}

/// Decodes a flags integer into a list of ChannelModes.
List<ChannelMode> decodeModeFlags(int flags) {
  final modes = <ChannelMode>[];
  // Check each mode's flag bit. Use a defined order and avoid duplicates
  // (subscribe and messageSubscribe share a bit).
  if (flags & ChannelMode.presence.flagBit != 0) {
    modes.add(ChannelMode.presence);
  }
  if (flags & ChannelMode.publish.flagBit != 0) {
    modes.add(ChannelMode.publish);
  }
  if (flags & ChannelMode.subscribe.flagBit != 0) {
    modes.add(ChannelMode.subscribe);
  }
  if (flags & ChannelMode.presenceSubscribe.flagBit != 0) {
    modes.add(ChannelMode.presenceSubscribe);
  }
  if (flags & ChannelMode.objectSubscribe.flagBit != 0) {
    modes.add(ChannelMode.objectSubscribe);
  }
  if (flags & ChannelMode.objectPublish.flagBit != 0) {
    modes.add(ChannelMode.objectPublish);
  }
  if (flags & ChannelMode.annotationPublish.flagBit != 0) {
    modes.add(ChannelMode.annotationPublish);
  }
  if (flags & ChannelMode.annotationSubscribe.flagBit != 0) {
    modes.add(ChannelMode.annotationSubscribe);
  }
  return modes;
}
