import 'log_level.dart';

/// Signature for log handlers.
typedef LogHandler = void Function(LogLevel level, String message);
