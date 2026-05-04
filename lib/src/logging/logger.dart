import 'log_handler.dart';
import 'log_level.dart';

/// Logger for the Ably SDK.
///
/// Created once per client instance from [ClientOptions.logLevel] and
/// [ClientOptions.logHandler], then threaded to all components.
class Logger {
  /// Creates a logger with the given [level] and optional [handler].
  ///
  /// If no handler is provided, logs are printed to stdout.
  Logger({required LogLevel level, LogHandler? handler})
      : _level = level,
        _handler = handler ?? _defaultHandler;

  final LogLevel _level;
  final LogHandler _handler;

  /// Whether a message at [level] would be logged.
  ///
  /// Use this to guard expensive context map construction:
  /// ```dart
  /// if (logger.shouldLog(LogLevel.verbose)) {
  ///   logger.verbose('Detail', {'data': expensiveSerialize()});
  /// }
  /// ```
  bool shouldLog(LogLevel level) => level.index <= _level.index;

  /// Logs a message at the given [level] with optional [context].
  void log(LogLevel level, String message,
      [Map<String, dynamic> context = const {}]) {
    if (shouldLog(level)) {
      _handler(level, message, context);
    }
  }

  /// Logs at [LogLevel.error].
  void error(String message, [Map<String, dynamic> context = const {}]) =>
      log(LogLevel.error, message, context);

  /// Logs at [LogLevel.warn].
  void warn(String message, [Map<String, dynamic> context = const {}]) =>
      log(LogLevel.warn, message, context);

  /// Logs at [LogLevel.info].
  void info(String message, [Map<String, dynamic> context = const {}]) =>
      log(LogLevel.info, message, context);

  /// Logs at [LogLevel.debug].
  void debug(String message, [Map<String, dynamic> context = const {}]) =>
      log(LogLevel.debug, message, context);

  /// Logs at [LogLevel.verbose].
  void verbose(String message, [Map<String, dynamic> context = const {}]) =>
      log(LogLevel.verbose, message, context);

  static void _defaultHandler(
      LogLevel level, String message, Map<String, dynamic> context) {
    final contextStr = context.isEmpty ? '' : ' $context';
    // ignore: avoid_print
    print('[ably] ${level.name}: $message$contextStr');
  }
}
