import 'dart:math';

import '../batch/batch_publish_spec.dart';
import '../batch/batch_result.dart';
import '../channels/channels.dart';
import '../rest/rest.dart';
import '../pagination/http_paginated_response.dart';
import 'base_client_impl.dart';
import 'rest_channels_impl.dart';

/// Implementation of the Rest client.
class RestImpl extends BaseClientImpl implements Rest {
  /// Creates a Rest client with the given options.
  RestImpl({
    required super.options,
    super.httpClient,
  }) {
    _channels = RestChannelsImpl(
      httpClient: ablyHttpClient,
      options: options,
    );
  }

  late final RestChannelsImpl _channels;

  @override
  RestChannels get channels => _channels;

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
    final response = await ablyHttpClient.request(
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
    final queryParams = uri.queryParameters.isNotEmpty
        ? Map<String, String>.from(uri.queryParameters)
        : null;

    final response = await ablyHttpClient.request(
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
    final response = await ablyHttpClient.request(
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
    if (options.idempotentRestPublishing) {
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
    ablyHttpClient.close();
  }
}
