import 'package:meta/meta.dart';

/// Parameters for REST presence queries.
@immutable
class RestPresenceParams {
  /// Creates RestPresenceParams.
  const RestPresenceParams({
    this.limit = 100,
    this.clientId,
    this.connectionId,
  });

  /// Maximum number of presence members to return.
  ///
  /// Defaults to 100, max is 1000.
  final int limit;

  /// Filter by client ID.
  final String? clientId;

  /// Filter by connection ID.
  final String? connectionId;

  /// Converts to query parameters.
  Map<String, String> toQueryParams() {
    return {
      'limit': limit.toString(),
      if (clientId != null) 'clientId': clientId!,
      if (connectionId != null) 'connectionId': connectionId!,
    };
  }
}
