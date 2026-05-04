import 'dart:convert';
import 'dart:math';

import '../auth/client_options.dart';
import '../channels/rest_annotations.dart';
import '../error/ably_exception.dart';
import '../error/error_info.dart';
import '../logging/logger.dart';
import '../message/annotation.dart';
import '../message/annotation_action.dart';
import '../pagination/paginated_result.dart';
import 'channel_rest_api.dart';
import 'http/http_client.dart';

/// Implementation of RestAnnotations.
///
/// Spec: RSAN1–RSAN3
class RestAnnotationsImpl implements RestAnnotations {
  RestAnnotationsImpl({
    required String channelName,
    required AblyHttpClient httpClient,
    required ClientOptions options,
    required Logger logger,
    required ChannelRestApi restApi,
  })  : _channelName = channelName,
        _httpClient = httpClient,
        _options = options,
        _logger = logger,
        _restApi = restApi,
        _random = Random();

  final String _channelName;
  final AblyHttpClient _httpClient;
  final ClientOptions _options;
  final Logger _logger;
  final ChannelRestApi _restApi;
  final Random _random;

  String get _encodedName => Uri.encodeComponent(_channelName);

  @override
  Future<void> publish(String messageSerial, Annotation annotation) async {
    _logger.info('annotations.publish() called', {
      'channel': _channelName,
      'messageSerial': messageSerial,
    });

    await _publishAnnotation(
      messageSerial,
      annotation,
      AnnotationAction.annotationCreate,
    );
  }

  @override
  Future<void> delete(String messageSerial, Annotation annotation) async {
    _logger.info('annotations.delete() called', {
      'channel': _channelName,
      'messageSerial': messageSerial,
    });

    await _publishAnnotation(
      messageSerial,
      annotation,
      AnnotationAction.annotationDelete,
    );
  }

  Future<void> _publishAnnotation(
    String messageSerial,
    Annotation annotation,
    AnnotationAction action,
  ) async {
    // RSAN1a3: type is required
    if (annotation.type == null || annotation.type!.isEmpty) {
      throw AblyException(
        message: 'Annotation type is required',
        errorInfo: const ErrorInfo(
          message: 'Annotation type is required',
          code: 40003,
          statusCode: 400,
        ),
      );
    }

    // Build the wire annotation — do not mutate the user's object
    final wireAnnotation = <String, dynamic>{};
    wireAnnotation['action'] = action.toInt();
    wireAnnotation['messageSerial'] = messageSerial;
    if (annotation.type != null) wireAnnotation['type'] = annotation.type;
    if (annotation.name != null) wireAnnotation['name'] = annotation.name;
    if (annotation.clientId != null) {
      wireAnnotation['clientId'] = annotation.clientId;
    }

    // RSAN1c3: Encode data per RSL4
    if (annotation.data != null) {
      final data = annotation.data;
      if (data is String) {
        wireAnnotation['data'] = data;
      } else if (data is Map || data is List) {
        wireAnnotation['data'] = json.encode(data);
        wireAnnotation['encoding'] = 'json';
      } else {
        wireAnnotation['data'] = json.encode(data);
        wireAnnotation['encoding'] = 'json';
      }
    }

    if (annotation.extras != null) {
      wireAnnotation['extras'] = annotation.extras!.toMap();
    }

    // RSAN1c4: Idempotent ID generation
    if (_options.idempotentRestPublishing && annotation.id == null) {
      wireAnnotation['id'] = '${_generateBaseIdempotencyKey()}:0';
    } else if (annotation.id != null) {
      wireAnnotation['id'] = annotation.id;
    }

    final path =
        '/channels/$_encodedName/messages/${Uri.encodeComponent(messageSerial)}/annotations';

    await _httpClient.request(
      'POST',
      path,
      body: [wireAnnotation],
    );
  }

  String _generateBaseIdempotencyKey() {
    final bytes = List<int>.generate(9, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }

  @override
  Future<PaginatedResult<Annotation>> get(
    String messageSerial, {
    Map<String, String>? params,
  }) async {
    _logger.info('annotations.get() called', {
      'channel': _channelName,
      'messageSerial': messageSerial,
    });

    return _restApi.getAnnotations(messageSerial, params);
  }
}
