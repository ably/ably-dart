import 'dart:math';

import '../batch/batch_publish_spec.dart';
import '../batch/batch_result.dart';
import '../channels/channels.dart';
import '../rest/rest.dart';
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
