import 'dart:async';

import 'derive_options.dart';
import 'realtime_channel.dart';
import 'realtime_channel_options.dart';

/// Collection of realtime channels.
///
/// Spec: RTS1
abstract class RealtimeChannels {
  /// Gets or creates a channel by name, optionally with channel options.
  ///
  /// Spec: RTS3, RTS3a, RTS3b, RTS3c
  RealtimeChannel get(String name, [RealtimeChannelOptions? options]);

  /// Gets a channel by name (shorthand for [get]).
  RealtimeChannel operator [](String name);

  /// Gets a derived channel with filter expressions.
  ///
  /// Spec: RTS5
  RealtimeChannel getDerived(
    String name,
    DeriveOptions deriveOptions, [
    RealtimeChannelOptions? channelOptions,
  ]);

  /// Returns whether a channel with the given name exists.
  bool exists(String name);

  /// Releases a channel, detaching it first if necessary.
  ///
  /// Spec: RTS4
  Future<void> release(String name);

  /// Returns the names of all channels in this collection.
  Iterable<String> get names;
}
