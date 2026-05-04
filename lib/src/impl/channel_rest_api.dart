import '../channels/channel_details.dart';
import '../channels/rest_history_params.dart';
import '../message/annotation.dart';
import '../message/message.dart';
import '../message/presence_message.dart';
import '../message/update_delete_result.dart';
import '../pagination/paginated_result.dart';
import 'http/http_client.dart';
import 'paginated_result_impl.dart';

/// Shared REST HTTP operations on a channel (history, status).
///
/// Used by both RestChannelImpl and RealtimeChannel to avoid
/// duplicating HTTP request/parse/paginate logic.
class ChannelRestApi {
  ChannelRestApi({
    required String channelName,
    required AblyHttpClient httpClient,
  })  : _channelName = channelName,
        _httpClient = httpClient;

  final String _channelName;
  final AblyHttpClient _httpClient;

  String get _encodedName => Uri.encodeComponent(_channelName);

  /// Retrieves channel message history.
  ///
  /// [extraQueryParams] allows callers to add additional query parameters
  /// (e.g. `fromSerial` for RTL10b untilAttach).
  ///
  /// Spec: RSL2, RTL10
  Future<PaginatedResult<Message>> history([
    RestHistoryParams? params,
    Map<String, String>? extraQueryParams,
  ]) async {
    final path = '/channels/$_encodedName/messages';
    final queryParams = params?.toQueryParams() ?? <String, String>{};
    if (extraQueryParams != null) {
      queryParams.addAll(extraQueryParams);
    }

    final response = await _httpClient.request(
      'GET',
      path,
      queryParams: queryParams,
    );

    final messages = PaginatedResultParser.parseMessages(response.body);

    return PaginatedResultImpl.fromResponse<Message>(
      response: response,
      items: messages,
      fetcher: _fetchHistoryPage,
    );
  }

  Future<PaginatedResult<Message>> _fetchHistoryPage(String url) async {
    final uri = Uri.parse(url);

    final response = await _httpClient.request(
      'GET',
      uri.path,
      queryParams: uri.queryParameters.isNotEmpty
          ? Map<String, String>.from(uri.queryParameters)
          : null,
    );

    final messages = PaginatedResultParser.parseMessages(response.body);

    return PaginatedResultImpl.fromResponse<Message>(
      response: response,
      items: messages,
      fetcher: _fetchHistoryPage,
    );
  }

  /// Retrieves presence history for this channel.
  ///
  /// Spec: RTP12, RSP4
  Future<PaginatedResult<PresenceMessage>> presenceHistory([
    RestHistoryParams? params,
  ]) async {
    final path = '/channels/$_encodedName/presence/history';
    final queryParams = params?.toQueryParams() ?? <String, String>{};

    final response = await _httpClient.request(
      'GET',
      path,
      queryParams: queryParams,
    );

    final messages = PaginatedResultParser.parsePresenceMessages(response.body);

    return PaginatedResultImpl.fromResponse<PresenceMessage>(
      response: response,
      items: messages,
      fetcher: _fetchPresenceHistoryPage,
    );
  }

  Future<PaginatedResult<PresenceMessage>> _fetchPresenceHistoryPage(
    String url,
  ) async {
    final uri = Uri.parse(url);

    final response = await _httpClient.request(
      'GET',
      uri.path,
      queryParams: uri.queryParameters.isNotEmpty
          ? Map<String, String>.from(uri.queryParameters)
          : null,
    );

    final messages = PaginatedResultParser.parsePresenceMessages(response.body);

    return PaginatedResultImpl.fromResponse<PresenceMessage>(
      response: response,
      items: messages,
      fetcher: _fetchPresenceHistoryPage,
    );
  }

  /// Retrieves a single message by serial.
  ///
  /// Spec: RSL11
  Future<Message> getMessage(String serial) async {
    final path =
        '/channels/$_encodedName/messages/${Uri.encodeComponent(serial)}';
    final response = await _httpClient.request('GET', path);
    return Message.fromMap(response.body as Map<String, dynamic>);
  }

  /// Retrieves all historical versions of a message.
  ///
  /// Spec: RSL14
  Future<PaginatedResult<Message>> getMessageVersions(
    String serial, [
    Map<String, String>? params,
  ]) async {
    final path =
        '/channels/$_encodedName/messages/${Uri.encodeComponent(serial)}/versions';
    final queryParams = params ?? <String, String>{};

    final response = await _httpClient.request(
      'GET',
      path,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );

    final messages = PaginatedResultParser.parseMessages(response.body);

    return PaginatedResultImpl.fromResponse<Message>(
      response: response,
      items: messages,
      fetcher: _fetchMessageVersionsPage,
    );
  }

  Future<PaginatedResult<Message>> _fetchMessageVersionsPage(
    String url,
  ) async {
    final uri = Uri.parse(url);

    final response = await _httpClient.request(
      'GET',
      uri.path,
      queryParams: uri.queryParameters.isNotEmpty
          ? Map<String, String>.from(uri.queryParameters)
          : null,
    );

    final messages = PaginatedResultParser.parseMessages(response.body);

    return PaginatedResultImpl.fromResponse<Message>(
      response: response,
      items: messages,
      fetcher: _fetchMessageVersionsPage,
    );
  }

  /// Sends a PATCH request to update, delete, or append a message.
  ///
  /// Spec: RSL15b
  Future<UpdateDeleteResult> patchMessage(
    String serial,
    Map<String, dynamic> body, {
    Map<String, String>? params,
  }) async {
    final path =
        '/channels/$_encodedName/messages/${Uri.encodeComponent(serial)}';
    final response = await _httpClient.request(
      'PATCH',
      path,
      queryParams: params,
      body: body,
    );
    return UpdateDeleteResult.fromMap(response.body as Map<String, dynamic>);
  }

  /// Retrieves annotations for a message.
  ///
  /// Spec: RSAN3
  Future<PaginatedResult<Annotation>> getAnnotations(
    String messageSerial, [
    Map<String, String>? params,
  ]) async {
    final path =
        '/channels/$_encodedName/messages/${Uri.encodeComponent(messageSerial)}/annotations';
    final queryParams = params ?? <String, String>{};

    final response = await _httpClient.request(
      'GET',
      path,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );

    final annotations = PaginatedResultParser.parseAnnotations(response.body);

    return PaginatedResultImpl.fromResponse<Annotation>(
      response: response,
      items: annotations,
      fetcher: _fetchAnnotationsPage,
    );
  }

  Future<PaginatedResult<Annotation>> _fetchAnnotationsPage(
    String url,
  ) async {
    final uri = Uri.parse(url);

    final response = await _httpClient.request(
      'GET',
      uri.path,
      queryParams: uri.queryParameters.isNotEmpty
          ? Map<String, String>.from(uri.queryParameters)
          : null,
    );

    final annotations = PaginatedResultParser.parseAnnotations(response.body);

    return PaginatedResultImpl.fromResponse<Annotation>(
      response: response,
      items: annotations,
      fetcher: _fetchAnnotationsPage,
    );
  }

  /// Retrieves the channel's current status and occupancy.
  ///
  /// Spec: RSL8
  Future<ChannelDetails> status() async {
    final path = '/channels/$_encodedName';

    final response = await _httpClient.request(
      'GET',
      path,
    );

    return ChannelDetails.fromMap(response.body as Map<String, dynamic>);
  }
}
