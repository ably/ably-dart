import 'realtime_channel.dart';

/// Collection of realtime channels.
///
/// Spec: RSN
class RealtimeChannels {
  /// Creates a RealtimeChannels collection.
  RealtimeChannels({
    required Object realtime,
  }) : _realtime = realtime;

  final Object _realtime;
  final Map<String, RealtimeChannel> _channels = {};

  /// Gets or creates a channel with the given name.
  ///
  /// If the channel already exists, returns the existing instance.
  /// If the channel does not exist, creates a new one.
  ///
  /// Spec: RSN3a
  RealtimeChannel get(String name) {
    if (_channels.containsKey(name)) {
      return _channels[name]!;
    }

    final channel = RealtimeChannel(
      realtime: _realtime,
      name: name,
    );
    _channels[name] = channel;
    return channel;
  }

  /// Gets or creates a channel with the given name (operator overload).
  ///
  /// Same as [get].
  ///
  /// Spec: RSN3a
  RealtimeChannel operator [](String name) => get(name);

  /// Checks if a channel with the given name exists.
  ///
  /// Returns true if the channel has been created (via get or []),
  /// false otherwise.
  ///
  /// Spec: RSN2
  bool exists(String name) {
    return _channels.containsKey(name);
  }

  /// Releases a channel, removing it from the collection.
  ///
  /// The channel will be detached if currently attached.
  ///
  /// Spec: RSN4
  Future<void> release(String name) async {
    final channel = _channels[name];
    if (channel != null) {
      // Detach the channel if it's attached
      await channel.detach();
      _channels.remove(name);
    }
  }

  /// Returns an iterator over all channel names.
  ///
  /// Spec: RSN2
  Iterable<String> get names => _channels.keys;

  /// Disposes all channels in the collection.
  void dispose() {
    for (final channel in _channels.values) {
      channel.dispose();
    }
    _channels.clear();
  }
}
