import '../message/message.dart';
import '../pagination/paginated_result.dart';
import '../presence/rest_presence.dart';
import 'rest_channel_options.dart';
import 'rest_history_params.dart';

/// A REST channel for publishing messages and retrieving history.
///
/// Spec: RSL
abstract class RestChannel {
  /// The name of this channel.
  String get name;

  /// The presence interface for this channel.
  RestPresence get presence;

  /// Publishes a message to this channel.
  ///
  /// You can specify either:
  /// - [message] - A pre-constructed Message object
  /// - [messages] - A list of Message objects
  /// - [name] and [data] - Individual message fields
  ///
  /// Optional [params] can be provided for additional querystring parameters.
  ///
  /// Spec: RSL1
  Future<void> publish({
    Message? message,
    List<Message>? messages,
    String? name,
    Object? data,
    Map<String, String>? params,
  });

  /// Retrieves the message history for this channel.
  ///
  /// Spec: RSL2
  Future<PaginatedResult<Message>> history([RestHistoryParams? params]);

  /// Sets options on this channel.
  Future<void> setOptions(RestChannelOptions options);
}
