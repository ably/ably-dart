import '../message/message.dart';
import '../message/message_operation.dart';
import '../message/update_delete_result.dart';
import '../pagination/paginated_result.dart';
import '../presence/rest_presence.dart';
import '../push/push_channel.dart';
import '../realtime/publish_result.dart';
import 'channel_details.dart';
import 'rest_annotations.dart';
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

  /// The annotations interface for this channel.
  ///
  /// Spec: RSL10
  RestAnnotations get annotations;

  /// The push interface for this channel.
  ///
  /// Spec: RSH7
  PushChannel get push;

  /// Publishes a message to this channel.
  ///
  /// You can specify either:
  /// - [message] - A pre-constructed Message object
  /// - [messages] - A list of Message objects
  /// - [name] and [data] - Individual message fields
  ///
  /// Optional [params] can be provided for additional querystring parameters.
  ///
  /// Returns a [PublishResult] containing the serials of the published messages.
  ///
  /// Spec: RSL1, RSL1n
  Future<PublishResult> publish({
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

  /// Retrieves the status of this channel.
  ///
  /// Returns a [ChannelDetails] object containing the channel's current
  /// status and occupancy metrics.
  ///
  /// Spec: RSL8
  Future<ChannelDetails> status();

  /// Sets options on this channel.
  Future<void> setOptions(RestChannelOptions options);

  /// Retrieves a message by its serial.
  ///
  /// [serial] is the unique serial of the message to retrieve.
  ///
  /// Spec: RSL11
  Future<Message> getMessage(String serial);

  /// Retrieves all historical versions of a message.
  ///
  /// [serial] is the unique serial of the message.
  /// Optional [params] are sent as querystring parameters.
  ///
  /// Spec: RSL14
  Future<PaginatedResult<Message>> getMessageVersions(
    String serial, {
    Map<String, String>? params,
  });

  /// Updates an existing message.
  ///
  /// The [message] must have a non-null [Message.serial].
  /// Optional [operation] provides metadata about the update.
  /// Optional [params] are sent as querystring parameters.
  ///
  /// Spec: RSL15
  Future<UpdateDeleteResult> updateMessage(
    Message message, {
    MessageOperation? operation,
    Map<String, String>? params,
  });

  /// Deletes an existing message.
  ///
  /// The [message] must have a non-null [Message.serial].
  /// Optional [operation] provides metadata about the delete.
  /// Optional [params] are sent as querystring parameters.
  ///
  /// Spec: RSL15
  Future<UpdateDeleteResult> deleteMessage(
    Message message, {
    MessageOperation? operation,
    Map<String, String>? params,
  });

  /// Appends data to an existing message.
  ///
  /// The [message] must have a non-null [Message.serial].
  /// Optional [operation] provides metadata about the append.
  /// Optional [params] are sent as querystring parameters.
  ///
  /// Spec: RSL15
  Future<UpdateDeleteResult> appendMessage(
    Message message, {
    MessageOperation? operation,
    Map<String, String>? params,
  });
}
