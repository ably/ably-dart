import 'dart:async';

import 'package:http/http.dart' as http;

/// Checks internet connectivity before attempting fallback hosts.
///
/// Makes a simple HTTP GET request to a known connectivity check URL
/// and verifies the response contains "yes" in the body.
///
/// Spec: RTN17j, REC3
class ConnectivityChecker {
  ConnectivityChecker({
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 5),
  })  : _httpClient = httpClient ?? http.Client(),
        _timeout = timeout;

  final http.Client _httpClient;
  final Duration _timeout;

  /// Checks if internet connectivity is available.
  ///
  /// Makes a GET request to the provided [url] (typically the connectivity
  /// check URL from ClientOptions) and returns true if:
  /// - The request succeeds (any 2xx status)
  /// - The response body contains the text "yes"
  ///
  /// Returns false if:
  /// - The request fails or times out
  /// - The response doesn't contain "yes"
  ///
  /// Spec: RTN17j
  Future<bool> check(String url) async {
    try {
      final response = await _httpClient.get(Uri.parse(url)).timeout(_timeout);

      // Check for success status code
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      // Check if body contains "yes"
      final body = response.body.toLowerCase();
      return body.contains('yes');
    } on TimeoutException {
      // Timeout means no connectivity
      return false;
    } catch (e) {
      // Any other error means no connectivity
      return false;
    }
  }

  /// Checks connectivity with a custom timeout.
  Future<bool> checkWithTimeout(String url, Duration timeout) async {
    try {
      final response = await _httpClient.get(Uri.parse(url)).timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final body = response.body.toLowerCase();
      return body.contains('yes');
    } on TimeoutException {
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Closes the underlying HTTP client.
  void close() {
    _httpClient.close();
  }
}
