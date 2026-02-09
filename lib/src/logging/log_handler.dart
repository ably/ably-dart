import 'log_level.dart';

/// Signature for log handlers.
///
/// [level] is the log severity level.
/// [message] is a fixed, human-readable description of the event.
/// [context] contains structured key-value pairs with event details.
typedef LogHandler = void Function(
  LogLevel level,
  String message,
  Map<String, dynamic> context,
);
