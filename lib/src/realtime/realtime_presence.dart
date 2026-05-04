import 'dart:async';

import '../channels/rest_history_params.dart';
import '../message/presence_message.dart';
import '../pagination/paginated_result.dart';
import '../presence/presence_action.dart';

/// Provides realtime presence operations for a channel.
///
/// Spec: RTP1
abstract class RealtimePresence {
  /// Whether the initial presence sync has completed.
  ///
  /// Spec: RTP13
  bool get syncComplete;

  /// Subscribes to presence events on this channel.
  ///
  /// If [action] or [actions] is provided, only matching events are delivered.
  ///
  /// Spec: RTP6, RTP6a, RTP6b, RTP6d, RTP6e
  void subscribe(
    void Function(PresenceMessage) listener, {
    PresenceAction? action,
    List<PresenceAction>? actions,
    bool attachOnSubscribe = true,
  });

  /// Unsubscribes from presence events.
  ///
  /// Spec: RTP7, RTP7a, RTP7b, RTP7c
  void unsubscribe({
    void Function(PresenceMessage)? listener,
    PresenceAction? action,
  });

  /// Enters the presence set for the current clientId.
  ///
  /// Spec: RTP8
  Future<void> enter([Object? data]);

  /// Updates presence data for the current clientId.
  ///
  /// Spec: RTP9
  Future<void> update([Object? data]);

  /// Leaves the presence set for the current clientId.
  ///
  /// Spec: RTP10
  Future<void> leave([Object? data]);

  /// Enters the presence set for a specific clientId.
  ///
  /// Spec: RTP14
  Future<void> enterClient(String clientId, [Object? data]);

  /// Updates presence data for a specific clientId.
  ///
  /// Spec: RTP15
  Future<void> updateClient(String clientId, [Object? data]);

  /// Leaves the presence set for a specific clientId.
  ///
  /// Spec: RTP15
  Future<void> leaveClient(String clientId, [Object? data]);

  /// Gets the current presence members on this channel.
  ///
  /// Spec: RTP11
  Future<List<PresenceMessage>> get({
    bool waitForSync = true,
    String? clientId,
    String? connectionId,
  });

  /// Gets the presence history for this channel.
  ///
  /// Spec: RTP12
  Future<PaginatedResult<PresenceMessage>> history([
    RestHistoryParams? params,
  ]);
}
