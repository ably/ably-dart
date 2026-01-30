import 'dart:math';

import 'package:http/http.dart' as http;

import '../auth/auth.dart';
import '../auth/client_options.dart';
import '../batch/batch_publish_spec.dart';
import '../batch/batch_result.dart';
import '../channels/channels.dart';
import '../client/rest.dart';
import '../error/ably_exception.dart';
import '../error/error_info.dart';
import '../pagination/http_paginated_response.dart';
import 'auth_impl.dart';
import 'http/http_client.dart';
import 'rest_channels_impl.dart';

/// Implementation of the Rest client.
class RestImpl implements Rest {
  /// Creates a Rest client with the given options.
  ///
  /// For testing, you can inject an [httpClient].
  RestImpl({
    required ClientOptions options,
    http.Client? httpClient,
  }) : _options = options {
    _validateOptions(options);

    // Create or use provided HTTP client
    final rawClient = httpClient ?? http.Client();

    _httpClient = AblyHttpClient(
      options: options,
      httpClient: rawClient,
    );

    _auth = AuthImpl(
      options: options,
      httpClient: _httpClient,
      rawHttpClient: rawClient,
    );

    // Wire up auth header provider
    _httpClient.authHeaderProvider = _auth.getAuthorizationHeader;

    _channels = RestChannelsImpl(
      httpClient: _httpClient,
      options: options,
    );
  }

  final ClientOptions _options;
  late final AblyHttpClient _httpClient;
  late final AuthImpl _auth;
  late final RestChannelsImpl _channels;

  void _validateOptions(ClientOptions options) {
    // Must have at least one authentication method
    final hasKey = options.key != null;
    final hasAuthCallback = options.authCallback != null;
    final hasAuthUrl = options.authUrl != null;
    final hasToken = options.token != null || options.tokenDetails != null;

    if (!hasKey && !hasAuthCallback && !hasAuthUrl && !hasToken) {
      throw const AblyException(
        message: 'No authentication method provided',
        errorInfo: ErrorInfo(
          message: 'No authentication method provided. '
              'Must provide key, authCallback, authUrl, or token.',
          code: 40106,
          statusCode: 401,
        ),
      );
    }

    // Validate key format if provided
    if (hasKey) {
      final keyParts = options.key!.split(':');
      if (keyParts.length != 2 || keyParts[0].isEmpty || keyParts[1].isEmpty) {
        throw const AblyException(
          message: 'Invalid API key format',
          errorInfo: ErrorInfo(
            message: 'Invalid API key format. Expected format: keyName:keySecret',
            code: 40101,
            statusCode: 401,
          ),
        );
      }

      // RSC18: Reject Basic auth over non-TLS connection
      // Basic auth should only be used if:
      // - No clientId (which would force token auth)
      // - No explicit useTokenAuth
      // - No other token auth methods
      final wouldUseBasicAuth = options.clientId == null &&
          options.useTokenAuth != true &&
          !hasAuthCallback &&
          !hasAuthUrl &&
          !hasToken;

      if (wouldUseBasicAuth && !options.tls) {
        throw const AblyException(
          message: 'Cannot use Basic authentication over non-TLS connection',
          errorInfo: ErrorInfo(
            message: 'Basic authentication (API key) requires TLS. '
                'Use token authentication for non-TLS connections.',
            code: 40103,
            statusCode: 401,
          ),
        );
      }
    }
  }

  @override
  ClientOptions get options => _options;

  @override
  Auth get auth => _auth;

  @override
  RestChannels get channels => _channels;

  @override
  Future<DateTime> time() async {
    final response = await _httpClient.request(
      'GET',
      '/time',
      authenticated: true,
    );

    final body = response.body;
    int timestamp;

    // Handle both array format (actual Ably API) and map format (some tests)
    if (body is List) {
      if (body.isEmpty) {
        throw const AblyException(
          message: 'Invalid time response',
          errorInfo: ErrorInfo(
            message: 'Server returned empty time response',
            code: 50000,
            statusCode: 500,
          ),
        );
      }
      timestamp = body[0] as int;
    } else if (body is Map && body.containsKey('time')) {
      timestamp = body['time'] as int;
    } else {
      throw const AblyException(
        message: 'Invalid time response',
        errorInfo: ErrorInfo(
          message: 'Invalid time response format',
          code: 50000,
          statusCode: 500,
        ),
      );
    }

    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  @override
  Future<HttpPaginatedResponse<dynamic>> request(
    String method,
    String path, {
    int? version,
    Map<String, String>? params,
    Map<String, String>? headers,
    Object? body,
  }) async {
    // Ensure path starts with /
    final normalizedPath = path.startsWith('/') ? path : '/$path';

    // Build query parameters
    final queryParams = Map<String, String>.from(params ?? {});

    // Make the request
    final response = await _httpClient.request(
      method,
      normalizedPath,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
      body: body,
      authenticated: true,
      customHeaders: headers,
      customVersion: version,
    );

    // Parse response items
    final responseBody = response.body;
    List<dynamic> items;

    if (responseBody is List) {
      items = responseBody;
    } else if (responseBody == null) {
      items = [];
    } else {
      // Non-array response - wrap in a list
      items = [responseBody];
    }

    // Store the original path for pagination
    final originalPath = normalizedPath;

    return HttpPaginatedResponseImpl.fromResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      items: items,
      firstUrl: originalPath,
      fetcher: (url) => _fetchPage(url, method, headers, version),
    );
  }

  Future<HttpPaginatedResponse<dynamic>> _fetchPage(
    String url,
    String method,
    Map<String, String>? headers,
    int? version,
  ) async {
    final uri = Uri.parse(url);
    final path = uri.path;
    final queryParams =
        uri.queryParameters.isNotEmpty ? Map<String, String>.from(uri.queryParameters) : null;

    final response = await _httpClient.request(
      method,
      path,
      queryParams: queryParams,
      authenticated: true,
      customHeaders: headers,
      customVersion: version,
    );

    final responseBody = response.body;
    List<dynamic> items;

    if (responseBody is List) {
      items = responseBody;
    } else if (responseBody == null) {
      items = [];
    } else {
      items = [responseBody];
    }

    return HttpPaginatedResponseImpl.fromResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      items: items,
      firstUrl: path,
      fetcher: (nextUrl) => _fetchPage(nextUrl, method, headers, version),
    );
  }

  @override
  Future<List<BatchResult>> batchPublish(
    Object spec, {
    Map<String, String>? params,
  }) async {
    // Convert spec to list format
    List<Map<String, dynamic>> specList;
    final bool singleSpec;

    if (spec is BatchPublishSpec) {
      singleSpec = true;
      specList = [_prepareBatchSpec(spec)];
    } else if (spec is List<BatchPublishSpec>) {
      singleSpec = false;
      specList = spec.map(_prepareBatchSpec).toList();
    } else {
      throw ArgumentError(
        'spec must be a BatchPublishSpec or List<BatchPublishSpec>',
      );
    }

    // Build request body
    final body = singleSpec ? specList.first : specList;

    // Make the request
    final response = await _httpClient.request(
      'POST',
      '/messages',
      queryParams: params,
      body: body,
    );

    // Parse results
    final responseBody = response.body;
    List<Map<String, dynamic>> resultList;

    if (responseBody is List) {
      resultList = responseBody.cast<Map<String, dynamic>>();
    } else if (responseBody is Map) {
      resultList = [responseBody as Map<String, dynamic>];
    } else {
      return [];
    }

    return resultList.map(BatchResult.fromMap).toList();
  }

  Map<String, dynamic> _prepareBatchSpec(BatchPublishSpec spec) {
    final specMap = spec.toMap();

    // RSC22d: Generate idempotent IDs if enabled
    if (_options.idempotentRestPublishing) {
      final messages = specMap['messages'] as List;
      for (var i = 0; i < messages.length; i++) {
        final message = messages[i] as Map<String, dynamic>;
        // Only generate ID if not already set (RSC22d3)
        if (message['id'] == null) {
          message['id'] = _generateIdempotentId(i);
        }
      }
    }

    return specMap;
  }

  String _generateIdempotentId(int index) {
    // Generate a unique base ID for this batch
    final random = Random();
    final bytes = List<int>.generate(9, (_) => random.nextInt(256));
    final base = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$base:$index';
  }

  @override
  Future<void> close() async {
    _httpClient.close();
  }
}
