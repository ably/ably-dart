import 'rest_channel.dart';

/// Manages REST channels.
abstract class RestChannels implements Iterable<RestChannel> {
  /// Gets or creates a channel with the given name.
  RestChannel get(String name);

  /// Shorthand for [get].
  RestChannel operator [](String name) => get(name);

  /// Checks if a channel with the given name exists.
  bool exists(String name);

  /// Releases a channel, freeing any associated resources.
  void release(String name);
}
