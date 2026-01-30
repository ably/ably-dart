import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../auth/client_options.dart';
import '../../error/ably_exception.dart';
import '../../error/error_info.dart';
import 'constants.dart';

/// Response from an Ably HTTP request.
class AblyHttpResponse {
  AblyHttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  /// HTTP status code.
  final int statusCode;

  /// Response headers (lowercase keys).
  final Map<String, String> headers;

  /// Parsed response body (usually Map or List).
  final dynamic body;

  /// Whether the response indicates success (2xx).
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Link header for pagination.
  String? get linkHeader => headers[HttpHeaders.link.toLowerCase()];

  /// Ably error code from headers.
  int? get errorCode {
    final code = headers[HttpHeaders.ablyErrorCode.toLowerCase()];
    return code != null ? int.tryParse(code) : null;
  }

  /// Ably error message from headers.
  String? get errorMessage =>
      headers[HttpHeaders.ablyErrorMessage.toLowerCase()];
}

/// Function type for obtaining an authorization header.
typedef AuthHeaderProvider = Future<String> Function();

/// HTTP client wrapper for Ably REST API.
class AblyHttpClient {
  AblyHttpClient({
    required ClientOptions options,
    http.Client? httpClient,
    AuthHeaderProvider? authHeaderProvider,
  })  : _options = options,
        _httpClient = httpClient ?? http.Client(),
        _authHeaderProvider = authHeaderProvider,
        _random = Random();

  final ClientOptions _options;
  final http.Client _httpClient;
  final AuthHeaderProvider? _authHeaderProvider;
  final Random _random;

  // Track fallback host failures
  DateTime? _fallbackHostsUnavailableSince;
  final List<String> _failedHosts = [];

  /// Set the auth header provider (called after Auth is initialized).
  AuthHeaderProvider? authHeaderProvider;

  /// Makes an HTTP request to the Ably REST API.
  Future<AblyHttpResponse> request(
    String method,
    String path, {
    Map<String, String>? queryParams,
    Object? body,
    bool authenticated = true,
  }) async {
    final effectiveQueryParams = Map<String, String>.from(queryParams ?? {});

    // Add request_id if configured (RSC7c)
    if (_options.addRequestIds) {
      effectiveQueryParams['request_id'] = _generateRequestId();
    }

    // Try primary host first, then fallbacks
    final hosts = _getHostsToTry();
    AblyException? lastException;

    for (final host in hosts) {
      try {
        final response = await _makeRequest(
          method,
          host,
          path,
          queryParams: effectiveQueryParams,
          body: body,
          authenticated: authenticated,
        );

        // If we used a fallback host successfully, clear failure tracking
        if (host != _options.effectiveRestHost) {
          _failedHosts.clear();
          _fallbackHostsUnavailableSince = null;
        }

        return response;
      } on AblyException catch (e) {
        lastException = e;

        // Only retry on certain errors (5xx, network errors)
        if (!_shouldRetryOnHost(e)) {
          rethrow;
        }

        // Mark this host as failed
        if (!_failedHosts.contains(host)) {
          _failedHosts.add(host);
        }
      }
    }

    throw lastException ??
        const AblyException(
          message: 'All hosts failed',
          errorInfo: ErrorInfo(
            message: 'All hosts failed',
            statusCode: 500,
          ),
        );
  }

  Future<AblyHttpResponse> _makeRequest(
    String method,
    String host,
    String path, {
    Map<String, String>? queryParams,
    Object? body,
    bool authenticated = true,
  }) async {
    // Build URL
    final scheme = _options.tls ? 'https' : 'http';
    final port = _options.effectivePort;
    final hostWithPort =
        port == (_options.tls ? 443 : 80) ? host : '$host:$port';
    var uri = Uri.parse('$scheme://$hostWithPort$path');

    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    // Build headers - use msgpack headers if useBinaryProtocol, otherwise JSON
    final contentType = _options.useBinaryProtocol
        ? ContentTypes.msgpack
        : ContentTypes.json;
    final headers = <String, String>{
      HttpHeaders.ablyVersion: ablyProtocolVersion,
      HttpHeaders.ablyAgent: _buildAgentString(),
      HttpHeaders.accept: contentType,
    };

    if (body != null) {
      headers[HttpHeaders.contentType] = contentType;
    }

    // Add auth header
    if (authenticated) {
      final provider = authHeaderProvider ?? _authHeaderProvider;
      if (provider != null) {
        headers[HttpHeaders.authorization] = await provider();
      }
    }

    // Make request
    http.Response response;
    try {
      final request = http.Request(method, uri);
      request.headers.addAll(headers);

      if (body != null) {
        request.body = json.encode(body);
      }

      final streamedResponse = await _httpClient
          .send(request)
          .timeout(Duration(milliseconds: _options.httpRequestTimeout));
      response = await http.Response.fromStream(streamedResponse);
    } on TimeoutException {
      throw AblyException(
        message: 'Request timeout',
        errorInfo: ErrorInfo(
          message: 'Request timeout after ${_options.httpRequestTimeout}ms',
          statusCode: 408,
          code: 50003,
        ),
      );
    } catch (e) {
      throw AblyException(
        message: 'Network error: $e',
        errorInfo: ErrorInfo(
          message: 'Network error: $e',
          statusCode: 500,
          code: 80000,
        ),
      );
    }

    // Normalize headers to lowercase keys for case-insensitive lookup
    final normalizedHeaders = <String, String>{};
    response.headers.forEach((key, value) {
      normalizedHeaders[key.toLowerCase()] = value;
    });

    // Check Content-Type for supported types (RSC8e)
    final responseContentType = normalizedHeaders['content-type'] ?? '';
    final isJsonResponse = responseContentType.contains('application/json');
    final isMsgpackResponse = responseContentType.contains('application/x-msgpack');
    final isSupported = isJsonResponse || isMsgpackResponse || responseContentType.isEmpty;

    // Parse response body
    dynamic parsedBody;
    if (response.body.isNotEmpty) {
      if (isJsonResponse || contentType.isEmpty) {
        try {
          parsedBody = json.decode(response.body);
        } catch (_) {
          // Response might not be valid JSON
          parsedBody = response.body;
        }
      } else {
        parsedBody = response.body;
      }
    }

    final ablyResponse = AblyHttpResponse(
      statusCode: response.statusCode,
      headers: normalizedHeaders,
      body: parsedBody,
    );

    // Check for errors
    if (!ablyResponse.isSuccess) {
      throw _parseError(ablyResponse, queryParams?['request_id']);
    }

    // For successful responses, check Content-Type support
    if (!isSupported && response.body.isNotEmpty) {
      throw AblyException(
        message: 'Unsupported Content-Type',
        errorInfo: ErrorInfo(
          message: 'Unsupported Content-Type: $responseContentType. '
              'Expected application/json or application/x-msgpack.',
          code: 40013,
          statusCode: 400,
          requestId: queryParams?['request_id'],
        ),
      );
    }

    return ablyResponse;
  }

  String _buildAgentString() {
    final agents = [ablyAgent];

    if (_options.agents != null) {
      for (final entry in _options.agents!.entries) {
        agents.add('${entry.key}/${entry.value}');
      }
    }

    return agents.join(' ');
  }

  String _generateRequestId() {
    final bytes = List<int>.generate(12, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).substring(0, 16);
  }

  List<String> _getHostsToTry() {
    final hosts = <String>[_options.effectiveRestHost];

    // Check if we should try fallback hosts
    final fallbacks = _options.fallbackHosts ?? defaultFallbackHosts;

    // Don't use fallbacks if within fallbackRetryTimeout of failure
    if (_fallbackHostsUnavailableSince != null) {
      final elapsed =
          DateTime.now().difference(_fallbackHostsUnavailableSince!);
      if (elapsed.inMilliseconds < _options.fallbackRetryTimeout) {
        return hosts;
      }
      _fallbackHostsUnavailableSince = null;
      _failedHosts.clear();
    }

    // Add fallback hosts (shuffled, excluding failed ones)
    final availableFallbacks =
        fallbacks.where((h) => !_failedHosts.contains(h)).toList();
    availableFallbacks.shuffle(_random);

    // Limit to httpMaxRetryCount
    final maxRetries = _options.httpMaxRetryCount;
    hosts.addAll(availableFallbacks.take(maxRetries));

    return hosts;
  }

  bool _shouldRetryOnHost(AblyException e) {
    final statusCode = e.statusCode;
    if (statusCode == null) return true; // Network error

    // Retry on 5xx errors
    if (statusCode >= 500 && statusCode < 600) return true;

    // Don't retry on 4xx errors
    return false;
  }

  AblyException _parseError(AblyHttpResponse response, String? requestId) {
    ErrorInfo errorInfo;

    if (response.body is Map && response.body['error'] != null) {
      final errorMap = response.body['error'] as Map<String, dynamic>;
      if (requestId != null) {
        errorMap['requestId'] = requestId;
      }
      errorInfo = ErrorInfo.fromMap(errorMap);
    } else {
      errorInfo = ErrorInfo(
        statusCode: response.statusCode,
        code: response.errorCode,
        message: response.errorMessage ?? 'HTTP ${response.statusCode}',
        requestId: requestId,
      );
    }

    return AblyException.fromErrorInfo(errorInfo);
  }

  /// Closes the HTTP client.
  void close() {
    _httpClient.close();
  }
}
