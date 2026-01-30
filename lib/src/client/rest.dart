import 'package:http/http.dart' as http;

import '../auth/auth.dart';
import '../auth/client_options.dart';
import '../channels/channels.dart';
import '../impl/rest_impl.dart';

/// The Ably REST client.
///
/// Provides stateless access to the Ably REST API for publishing messages
/// and retrieving channel history.
///
/// Spec: RSC
abstract class Rest {
  /// Creates a REST client with the given options.
  ///
  /// For testing, you can optionally provide an [httpClient].
  ///
  /// Spec: RSC1
  factory Rest({
    required ClientOptions options,
    http.Client? httpClient,
  }) {
    return RestImpl(options: options, httpClient: httpClient);
  }

  /// Creates a REST client from an API key.
  ///
  /// This is a convenience constructor equivalent to:
  /// ```dart
  /// Rest(options: ClientOptions.fromKey(key))
  /// ```
  ///
  /// For testing, you can optionally provide an [httpClient].
  ///
  /// Spec: RSC1
  factory Rest.fromKey(String key, {http.Client? httpClient}) {
    return Rest(options: ClientOptions.fromKey(key), httpClient: httpClient);
  }

  /// The client options.
  ClientOptions get options;

  /// The auth interface for this client.
  ///
  /// Provides methods for token management and authentication.
  Auth get auth;

  /// The channels interface for this client.
  ///
  /// Provides access to REST channels for publishing and history.
  RestChannels get channels;

  /// Gets the current server time.
  ///
  /// Useful for ensuring accurate timestamps in token requests.
  Future<DateTime> time();

  /// Closes this client and releases any resources.
  Future<void> close();
}
