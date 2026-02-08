import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import '../auth/auth.dart';
import '../auth/client_options.dart';
import '../impl/realtime_impl.dart';
import 'connection.dart';
import 'realtime_channels.dart';
import 'timer_manager.dart';
import 'websocket_client.dart';

/// The Ably Realtime client.
///
/// Provides access to realtime messaging, presence, and connection management.
///
/// Spec: RTC1
abstract class Realtime {
  /// Creates a Realtime client with the given options.
  ///
  /// If [key] is provided, it will be used instead of options.key.
  ///
  /// Spec: RTC1a
  factory Realtime({
    ClientOptions? options,
    String? key,
  }) {
    final resolvedOptions = _resolveOptions(options, key);
    return RealtimeImpl(options: resolvedOptions);
  }

  /// Creates a Realtime client from an API key.
  ///
  /// This is a convenience constructor equivalent to:
  /// ```dart
  /// Realtime(options: ClientOptions.fromKey(key))
  /// ```
  ///
  /// Spec: RTC1b
  factory Realtime.fromKey(String key) {
    return Realtime(options: ClientOptions.fromKey(key));
  }

  /// Creates a Realtime client with test configuration.
  ///
  /// This factory is only for testing purposes and allows injection of
  /// mock dependencies like WebSocketClient and http.Client.
  ///
  /// Example:
  /// ```dart
  /// final client = Realtime.forTesting(
  ///   options: ClientOptions(key: 'test'),
  ///   webSocketClient: mockWebSocketClient,
  ///   httpClient: mockHttpClient,
  /// );
  /// ```
  @visibleForTesting
  factory Realtime.forTesting({
    required ClientOptions options,
    WebSocketClient? webSocketClient,
    http.Client? httpClient,
    TimerManager? timerManager,
  }) {
    return RealtimeImpl(
      options: options,
      webSocketClient: webSocketClient,
      httpClient: httpClient,
      timerManager: timerManager,
    );
  }

  /// The connection object for this client.
  ///
  /// Provides access to connection state, events, and control.
  ///
  /// Spec: RTC2
  Connection get connection;

  /// The channels collection for this client.
  ///
  /// Provides access to realtime channels for pub/sub messaging.
  ///
  /// Spec: RTC3
  RealtimeChannels get channels;

  /// The auth object for this client.
  ///
  /// Provides methods for token management and authentication.
  ///
  /// Spec: RTC4
  Auth get auth;

  /// The client options for this client.
  ///
  /// Spec: RTC5
  ClientOptions get options;

  /// The clientId for this client.
  ///
  /// Returns the clientId from auth if set.
  ///
  /// Spec: RTC17
  String? get clientId;

  /// Retrieves the server time from the Ably service.
  ///
  /// This is a direct proxy to the REST time() method (RSC16).
  /// The request does not require authentication.
  ///
  /// Spec: RTC6, RTC6a
  Future<DateTime> time();

  /// Explicitly initiates a connection to Ably.
  ///
  /// If already connected or connecting, this is a no-op.
  ///
  /// Spec: RTC1c
  Future<void> connect();

  /// Closes the connection to Ably.
  ///
  /// All channels will be detached and the connection will be closed.
  ///
  /// Spec: RTC16
  Future<void> close();

  /// Internal helper to resolve options from various constructor parameters.
  static ClientOptions _resolveOptions(ClientOptions? options, String? key) {
    if (key != null) {
      // Key provided - use it to override options
      if (options != null) {
        return options.copyWith(key: key);
      }
      return ClientOptions.fromKey(key);
    }

    if (options != null) {
      return options;
    }

    // No options or key provided
    throw ArgumentError(
      'Either options or key must be provided',
    );
  }
}
