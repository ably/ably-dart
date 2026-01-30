import '../channels/rest_history_params.dart';
import '../message/presence_message.dart';
import '../pagination/paginated_result.dart';
import 'rest_presence_params.dart';

/// Provides REST presence operations for a channel.
abstract class RestPresence {
  /// Gets the current presence members on this channel.
  ///
  /// Returns a [PaginatedResult] containing [PresenceMessage] items.
  Future<PaginatedResult<PresenceMessage>> get([RestPresenceParams? params]);

  /// Gets the presence history for this channel.
  ///
  /// Returns a [PaginatedResult] containing [PresenceMessage] items.
  Future<PaginatedResult<PresenceMessage>> history([RestHistoryParams? params]);
}
