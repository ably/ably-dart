import 'package:meta/meta.dart';

/// Direction for stats queries.
///
/// Spec: RSC6b2
enum StatsDirection {
  /// Oldest entries first.
  forwards,

  /// Newest entries first (default).
  backwards,
}

/// Time unit for stats aggregation.
///
/// Spec: RSC6b4
enum StatsUnit {
  /// Per-minute stats.
  minute,

  /// Per-hour stats.
  hour,

  /// Per-day stats.
  day,

  /// Per-month stats.
  month,
}

/// Application statistics for a time interval.
///
/// Spec: RSC6a
@immutable
class Stats {
  const Stats({
    required this.intervalId,
    this.unit,
    this.all,
    this.inbound,
    this.outbound,
    this.persisted,
    this.connections,
    this.channels,
    this.apiRequests,
    this.tokenRequests,
  });

  /// Creates a Stats object from a JSON map.
  factory Stats.fromMap(Map<String, dynamic> map) {
    return Stats(
      intervalId: map['intervalId'] as String,
      unit: map['unit'] as String?,
      all: map['all'] != null
          ? Map<String, dynamic>.from(map['all'] as Map)
          : null,
      inbound: map['inbound'] != null
          ? Map<String, dynamic>.from(map['inbound'] as Map)
          : null,
      outbound: map['outbound'] != null
          ? Map<String, dynamic>.from(map['outbound'] as Map)
          : null,
      persisted: map['persisted'] != null
          ? Map<String, dynamic>.from(map['persisted'] as Map)
          : null,
      connections: map['connections'] != null
          ? Map<String, dynamic>.from(map['connections'] as Map)
          : null,
      channels: map['channels'] != null
          ? Map<String, dynamic>.from(map['channels'] as Map)
          : null,
      apiRequests: map['apiRequests'] != null
          ? Map<String, dynamic>.from(map['apiRequests'] as Map)
          : null,
      tokenRequests: map['tokenRequests'] != null
          ? Map<String, dynamic>.from(map['tokenRequests'] as Map)
          : null,
    );
  }

  /// The interval ID (e.g., "2024-01-01:00:00").
  final String intervalId;

  /// The unit of the interval (e.g., "minute", "hour", "day", "month").
  final String? unit;

  /// Aggregate stats for all message types.
  final Map<String, dynamic>? all;

  /// Stats for inbound messages.
  final Map<String, dynamic>? inbound;

  /// Stats for outbound messages.
  final Map<String, dynamic>? outbound;

  /// Stats for persisted messages.
  final Map<String, dynamic>? persisted;

  /// Connection stats.
  final Map<String, dynamic>? connections;

  /// Channel stats.
  final Map<String, dynamic>? channels;

  /// API request stats.
  final Map<String, dynamic>? apiRequests;

  /// Token request stats.
  final Map<String, dynamic>? tokenRequests;
}
