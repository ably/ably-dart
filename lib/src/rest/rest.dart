import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import '../auth/auth.dart';
import '../auth/client_options.dart';
import '../batch/batch_publish_spec.dart';
import '../batch/batch_result.dart';
import '../channels/channels.dart';
import '../impl/rest_impl.dart';
import '../pagination/http_paginated_response.dart';

/// The Ably REST client.
///
/// Provides stateless access to the Ably REST API for publishing messages
/// and retrieving channel history.
///
/// Spec: RSC
abstract class Rest {
  /// Creates a REST client with the given options.
  ///
  /// Spec: RSC1
  factory Rest({
    required ClientOptions options,
  }) {
    return RestImpl(options: options);
  }

  /// Creates a REST client from an API key.
  ///
  /// This is a convenience constructor equivalent to:
  /// ```dart
  /// Rest(options: ClientOptions.fromKey(key))
  /// ```
  ///
  /// Spec: RSC1
  factory Rest.fromKey(String key) {
    return Rest(options: ClientOptions.fromKey(key));
  }

  /// Creates a REST client with test configuration.
  ///
  /// This factory is only for testing purposes and allows injection of
  /// a mock [httpClient].
  @visibleForTesting
  factory Rest.forTesting({
    required ClientOptions options,
    http.Client? httpClient,
  }) {
    return RestImpl(options: options, httpClient: httpClient);
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

  /// Makes an arbitrary HTTP request to the Ably REST API.
  ///
  /// This provides access to any REST API endpoint, including those not
  /// directly exposed by other client methods.
  ///
  /// The [method] parameter specifies the HTTP method (GET, POST, PUT, etc.).
  /// The [path] parameter specifies the API path (e.g., '/channels/foo/messages').
  ///
  /// Optional parameters:
  /// - [version]: Explicit API version (defaults to current version).
  /// - [params]: Query parameters to add to the request URL.
  /// - [headers]: Additional headers to include in the request.
  /// - [body]: Request body (will be JSON-encoded).
  ///
  /// Returns an [HttpPaginatedResponse] containing the response items and
  /// HTTP metadata (status code, headers, error codes).
  ///
  /// Spec: RSC19
  Future<HttpPaginatedResponse<dynamic>> request(
    String method,
    String path, {
    int? version,
    Map<String, String>? params,
    Map<String, String>? headers,
    Object? body,
  });

  /// Publishes messages to multiple channels in a single request.
  ///
  /// You can provide either:
  /// - A single [BatchPublishSpec] to publish to one or more channels
  /// - A list of [BatchPublishSpec] objects for multiple publish operations
  ///
  /// Returns a list of [BatchResult] objects indicating success or failure
  /// for each channel. When publishing to multiple channels, the result
  /// contains one entry per channel.
  ///
  /// Spec: RSC22
  Future<List<BatchResult>> batchPublish(
    Object spec, {
    Map<String, String>? params,
  });

  /// Closes this client and releases any resources.
  Future<void> close();
}
