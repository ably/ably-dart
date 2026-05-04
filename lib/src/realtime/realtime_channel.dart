import 'dart:async';

import '../channels/channel_details.dart';
import '../channels/rest_history_params.dart';
import '../error/error_info.dart';
import '../message/message.dart';
import '../message/message_filter.dart';
import '../message/message_operation.dart';
import '../message/update_delete_result.dart';
import '../pagination/paginated_result.dart';
import '../push/push_channel.dart';
import 'channel_event.dart';
import 'channel_mode.dart';
import 'channel_state.dart';
import 'channel_state_change.dart';
import 'publish_result.dart';
import 'realtime_annotations.dart';
import 'realtime_channel_options.dart';
import 'realtime_presence.dart';

/// Properties of a realtime channel's state.
///
/// Spec: RTL15, CP1, CP2
class ChannelProperties {
  /// The `channelSerial` from the most recent ATTACHED ProtocolMessage.
  ///
  /// Used for `untilAttach` queries (RTL10b).
  ///
  /// Spec: RTL15a, CP2a
  String? attachSerial;

  /// The last `channelSerial` received on the channel.
  ///
  /// Updated from MESSAGE, PRESENCE, ANNOTATION, OBJECT, or ATTACHED
  /// actions. Cleared when the channel enters DETACHED, SUSPENDED, or FAILED.
  ///
  /// Spec: RTL15b, CP2b
  String? channelSerial;
}

/// A realtime channel for pub/sub messaging.
///
/// Spec: RTL
abstract class RealtimeChannel {
  /// The channel name.
  String get name;

  /// The channel options.
  RealtimeChannelOptions get options;

  /// The current channel state.
  ///
  /// Spec: RTL2
  ChannelState get state;

  /// Channel properties (RTL15).
  ChannelProperties get properties;

  /// The channel modes, if set.
  ///
  /// Spec: RTL4m
  List<ChannelMode>? get modes;

  /// The presence object for this channel.
  ///
  /// Spec: RTL9
  RealtimePresence get presence;

  /// The annotations object for this channel.
  ///
  /// Spec: RTL26
  RealtimeAnnotations get annotations;

  /// The push interface for this channel.
  ///
  /// Spec: RSH7
  PushChannel get push;

  /// Error information for the current state (if failed).
  ///
  /// Spec: RTL4e
  ErrorInfo? get errorReason;

  /// Listens to channel state changes.
  ///
  /// If [event] is provided, only emits changes matching that event.
  /// If [event] is null, emits all state changes.
  ///
  /// Spec: RTL2
  Stream<ChannelStateChange> on([ChannelEvent? event]);

  /// Calls the listener immediately with null if already in the target state,
  /// otherwise registers a one-time listener for that state.
  void whenState(
    ChannelState targetState,
    void Function(ChannelStateChange?) listener,
  );

  /// Subscribes to messages on this channel.
  ///
  /// If [name] is provided, only messages with that name are delivered.
  ///
  /// Spec: RTL7, RTL7a, RTL7b, RTL7g, RTL7h
  void subscribe(void Function(Message) listener, {String? name});

  /// Subscribes to messages matching a [MessageFilter].
  ///
  /// Only messages matching all criteria in the filter are delivered to the
  /// listener (AND semantics). Uses the same implicit-attach and
  /// attachOnSubscribe behaviour as [subscribe].
  ///
  /// Spec: RTL22, RTL22a, RTL22b, RTL22c, RTL22d
  void subscribeFilter(
    MessageFilter filter,
    void Function(Message) listener,
  );

  /// Unsubscribes from messages on this channel.
  ///
  /// Spec: RTL8, RTL8a, RTL8b, RTL8c
  void unsubscribe({void Function(Message)? listener, String? name});

  /// Publishes a message on this channel.
  ///
  /// Spec: RTL6, RTL6j
  Future<PublishResult> publish({
    String? name,
    Object? data,
    Message? message,
    List<Message>? messages,
  });

  /// Attaches to this channel.
  ///
  /// Spec: RTL4
  Future<void> attach();

  /// Detaches from this channel.
  ///
  /// Spec: RTL5
  Future<void> detach();

  /// Retrieves message history for this channel via the REST API.
  ///
  /// Spec: RTL10, RTL10a, RTL10b, RTL10c
  Future<PaginatedResult<Message>> history([RestHistoryParams? params]);

  /// Retrieves a single message by serial via the REST API.
  ///
  /// Spec: RTL28
  Future<Message> getMessage(String serial);

  /// Retrieves all historical versions of a message via the REST API.
  ///
  /// Spec: RTL31
  Future<PaginatedResult<Message>> getMessageVersions(
    String serial, {
    Map<String, String>? params,
  });

  /// Updates a previously published message.
  ///
  /// Spec: RTL32
  Future<UpdateDeleteResult> updateMessage(
    Message message, {
    MessageOperation? operation,
    Map<String, String>? params,
  });

  /// Deletes a previously published message.
  ///
  /// Spec: RTL32
  Future<UpdateDeleteResult> deleteMessage(
    Message message, {
    MessageOperation? operation,
    Map<String, String>? params,
  });

  /// Appends to a previously published message.
  ///
  /// Spec: RTL32
  Future<UpdateDeleteResult> appendMessage(
    Message message, {
    MessageOperation? operation,
    Map<String, String>? params,
  });

  /// Retrieves the channel's current status and occupancy via the REST API.
  ///
  /// Spec: RSL8
  Future<ChannelDetails> status();

  /// Sets channel options, potentially triggering a re-attach.
  ///
  /// Spec: RTL16
  Future<void> setOptions(RealtimeChannelOptions options);
}
