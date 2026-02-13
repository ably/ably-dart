import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../auth/client_options.dart';
import '../channels/channel_details.dart';
import '../channels/rest_channel.dart';
import '../channels/rest_channel_options.dart';
import '../channels/rest_history_params.dart';
import '../error/ably_exception.dart';
import '../error/error_info.dart';
import '../logging/logger.dart';
import '../message/message.dart';
import '../pagination/paginated_result.dart';
import '../presence/rest_presence.dart';
import 'channel_rest_api.dart';
import 'http/http_client.dart';
import 'rest_presence_impl.dart';

/// Implementation of RestChannel.
class RestChannelImpl implements RestChannel {
  RestChannelImpl({
    required String name,
    required AblyHttpClient httpClient,
    required ClientOptions options,
    required Logger logger,
    RestChannelOptions? channelOptions,
  })  : _name = name,
        _httpClient = httpClient,
        _options = options,
        _logger = logger,
        _channelOptions = channelOptions,
        _random = Random() {
    _restApi = ChannelRestApi(channelName: name, httpClient: httpClient);
    _presence = RestPresenceImpl(
      channelName: name,
      httpClient: httpClient,
      logger: logger,
    );
  }

  final String _name;
  final AblyHttpClient _httpClient;
  final ClientOptions _options;
  final Logger _logger;
  RestChannelOptions? _channelOptions;
  late final ChannelRestApi _restApi;
  late final RestPresenceImpl _presence;
  final Random _random;

  // For idempotent publishing
  int _messageSerial = 0;
  String? _baseIdempotencyKey;

  @override
  String get name => _name;

  @override
  RestPresence get presence => _presence;

  @override
  Future<void> publish({
    Message? message,
    List<Message>? messages,
    String? name,
    Object? data,
    Map<String, String>? params,
  }) async {
    // Build the list of messages to publish
    final messagesToPublish = <Message>[];

    if (message != null) {
      messagesToPublish.add(message);
    } else if (messages != null) {
      messagesToPublish.addAll(messages);
    } else {
      // RSL1e: Accept null name and/or null data
      messagesToPublish.add(Message(name: name, data: data));
    }

    _logger.info('publish() called', {
      'channel': _name,
      'messageCount': messagesToPublish.length,
    });

    // Encode messages for publishing
    final encodedMessages = messagesToPublish.map(_encodeMessage).toList();

    // Check message size
    final jsonBody = json.encode(encodedMessages);
    if (jsonBody.length > _options.maxMessageSize) {
      _logger.error('Message exceeds maxMessageSize', {
        'size': jsonBody.length,
        'max': _options.maxMessageSize,
      });
      throw AblyException(
        message: 'Message size exceeds maximum',
        errorInfo: ErrorInfo(
          message:
              'Message size ${jsonBody.length} exceeds maximum ${_options.maxMessageSize}',
          code: 40009,
          statusCode: 400,
        ),
      );
    }

    // Add idempotency IDs if enabled (RSL1k)
    if (_options.idempotentRestPublishing) {
      _logger.debug('Added idempotent IDs');
      _addIdempotencyIds(encodedMessages);
    }

    // Publish - always send as array (RSL1b/RSL1c)
    final path = '/channels/${Uri.encodeComponent(_name)}/messages';
    await _httpClient.request(
      'POST',
      path,
      queryParams: params,
      body: encodedMessages,
    );
  }

  Map<String, dynamic> _encodeMessage(Message msg) {
    final encoded = <String, dynamic>{};

    if (msg.id != null) encoded['id'] = msg.id;
    if (msg.name != null) encoded['name'] = msg.name;
    if (msg.clientId != null) encoded['clientId'] = msg.clientId;
    if (msg.extras != null) encoded['extras'] = msg.extras!.toMap();

    // Encode data based on type (RSL4)
    if (msg.data != null) {
      final data = msg.data;
      if (data is String) {
        encoded['data'] = data;
      } else if (data is Uint8List) {
        // Binary data needs base64 encoding
        encoded['data'] = base64.encode(data);
        encoded['encoding'] = _combineEncodings('base64', msg.encoding);
      } else if (data is List || data is Map) {
        // JSON objects/arrays - encode as JSON string (RSL4c)
        encoded['data'] = json.encode(data);
        encoded['encoding'] = _combineEncodings('json', msg.encoding);
      } else {
        // Other types - convert to JSON string
        encoded['data'] = json.encode(data);
        encoded['encoding'] = _combineEncodings('json', msg.encoding);
      }
    }

    return encoded;
  }

  String? _combineEncodings(String? newEncoding, String? existingEncoding) {
    if (newEncoding == null) return existingEncoding;
    if (existingEncoding == null || existingEncoding.isEmpty) {
      return newEncoding;
    }
    return '$existingEncoding/$newEncoding';
  }

  void _addIdempotencyIds(List<Map<String, dynamic>> messages) {
    // Generate a new base key for each publish call (RSL1k3)
    final baseKey = _generateBaseIdempotencyKey();

    for (var i = 0; i < messages.length; i++) {
      if (messages[i]['id'] == null) {
        messages[i]['id'] = '$baseKey:$_messageSerial';
        _messageSerial++;
      }
    }
  }

  String _generateBaseIdempotencyKey() {
    // Generate a random base64 string (RSL1k1)
    final bytes = List<int>.generate(9, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }

  @override
  Future<PaginatedResult<Message>> history([RestHistoryParams? params]) {
    _logger.info('history() called', {'channel': _name});
    return _restApi.history(params);
  }

  @override
  Future<ChannelDetails> status() {
    _logger.info('status() called', {'channel': _name});
    return _restApi.status();
  }

  @override
  Future<void> setOptions(RestChannelOptions options) async {
    _logger.info('setOptions() called', {'channel': _name});
    _channelOptions = options;
    // Note: Encryption setup would go here if implemented
  }
}
