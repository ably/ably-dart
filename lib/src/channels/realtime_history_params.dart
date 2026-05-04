import 'package:meta/meta.dart';

import 'rest_history_params.dart';

/// Parameters for realtime channel history queries.
///
/// Extends [RestHistoryParams] with [untilAttach], which restricts
/// the query to messages received before the channel's current
/// attach point.
///
/// Spec: RTL10a, RTL10b
@immutable
class RealtimeHistoryParams extends RestHistoryParams {
  /// Creates RealtimeHistoryParams.
  const RealtimeHistoryParams({
    super.start,
    super.end,
    super.direction,
    super.limit,
    this.untilAttach = false,
  });

  /// If true, restricts the query to messages prior to the channel's
  /// most recent attach point, using `fromSerial` set to the
  /// channel's `properties.attachSerial`.
  ///
  /// The channel must be attached when this is true; otherwise
  /// an error is thrown.
  ///
  /// Spec: RTL10b
  final bool untilAttach;
}
