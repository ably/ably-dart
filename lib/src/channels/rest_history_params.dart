import 'package:meta/meta.dart';

/// Direction for history queries.
enum HistoryDirection {
  /// Oldest messages first.
  forwards,

  /// Newest messages first (default).
  backwards,
}

/// Parameters for REST channel history queries.
///
/// Spec: RSL2b
@immutable
class RestHistoryParams {
  /// Creates RestHistoryParams.
  const RestHistoryParams({
    this.start,
    this.end,
    this.direction = HistoryDirection.backwards,
    this.limit = 100,
  });

  /// Creates RestHistoryParams from a map of query parameters.
  factory RestHistoryParams.fromMap(Map<String, dynamic> map) {
    return RestHistoryParams(
      start: map['start'] != null
          ? (map['start'] is int
              ? map['start'] as int
              : int.parse(map['start'].toString()))
          : null,
      end: map['end'] != null
          ? (map['end'] is int
              ? map['end'] as int
              : int.parse(map['end'].toString()))
          : null,
      direction: map['direction'] == 'forwards'
          ? HistoryDirection.forwards
          : HistoryDirection.backwards,
      limit: map['limit'] != null
          ? (map['limit'] is int
              ? map['limit'] as int
              : int.parse(map['limit'].toString()))
          : 100,
    );
  }

  /// Start of the query time window, in milliseconds since Unix epoch.
  final int? start;

  /// End of the query time window, in milliseconds since Unix epoch.
  final int? end;

  /// Direction of the query.
  ///
  /// Defaults to [HistoryDirection.backwards] (newest first).
  final HistoryDirection direction;

  /// Maximum number of messages to return.
  ///
  /// Defaults to 100, max is 1000.
  final int limit;

  /// Returns the start time as a DateTime, if set.
  DateTime? get startAsDateTime =>
      start != null ? DateTime.fromMillisecondsSinceEpoch(start!) : null;

  /// Returns the end time as a DateTime, if set.
  DateTime? get endAsDateTime =>
      end != null ? DateTime.fromMillisecondsSinceEpoch(end!) : null;

  /// Converts to query parameters.
  Map<String, String> toQueryParams() {
    return {
      if (start != null) 'start': start.toString(),
      if (end != null) 'end': end.toString(),
      'direction':
          direction == HistoryDirection.forwards ? 'forwards' : 'backwards',
      'limit': limit.toString(),
    };
  }
}
