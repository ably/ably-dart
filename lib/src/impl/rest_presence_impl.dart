import '../channels/rest_history_params.dart';
import '../message/presence_message.dart';
import '../pagination/paginated_result.dart';
import '../presence/rest_presence.dart';
import '../presence/rest_presence_params.dart';
import 'http/http_client.dart';
import 'paginated_result_impl.dart';

/// Implementation of RestPresence.
class RestPresenceImpl implements RestPresence {
  RestPresenceImpl({
    required String channelName,
    required AblyHttpClient httpClient,
  })  : _channelName = channelName,
        _httpClient = httpClient;

  final String _channelName;
  final AblyHttpClient _httpClient;

  @override
  Future<PaginatedResult<PresenceMessage>> get([
    RestPresenceParams? params,
  ]) async {
    final path = '/channels/${Uri.encodeComponent(_channelName)}/presence';
    final queryParams = params?.toQueryParams() ?? {};

    final response = await _httpClient.request(
      'GET',
      path,
      queryParams: queryParams,
    );

    final messages = PaginatedResultParser.parsePresenceMessages(response.body);

    return PaginatedResultImpl.fromResponse<PresenceMessage>(
      response: response,
      items: messages,
      fetcher: (url) => _fetchPresencePage(url),
    );
  }

  @override
  Future<PaginatedResult<PresenceMessage>> history([
    RestHistoryParams? params,
  ]) async {
    final path = '/channels/${Uri.encodeComponent(_channelName)}/presence/history';
    final queryParams = params?.toQueryParams() ?? {};

    final response = await _httpClient.request(
      'GET',
      path,
      queryParams: queryParams,
    );

    final messages = PaginatedResultParser.parsePresenceMessages(response.body);

    return PaginatedResultImpl.fromResponse<PresenceMessage>(
      response: response,
      items: messages,
      fetcher: (url) => _fetchPresenceHistoryPage(url),
    );
  }

  Future<PaginatedResult<PresenceMessage>> _fetchPresencePage(String url) async {
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
      fetcher: (nextUrl) => _fetchPresencePage(nextUrl),
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
      fetcher: (nextUrl) => _fetchPresenceHistoryPage(nextUrl),
    );
  }
}
