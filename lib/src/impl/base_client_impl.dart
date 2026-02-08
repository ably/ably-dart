import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import '../auth/auth.dart';
import '../auth/client_options.dart';
import '../error/ably_exception.dart';
import '../error/error_info.dart';
import '../pagination/paginated_result.dart';
import '../stats/stats.dart';
import 'auth_impl.dart';
import 'http/http_client.dart';
import 'paginated_result_impl.dart';

/// Shared base class for Rest and Realtime client implementations.
///
/// Contains the HTTP client, auth setup, options validation, and
/// methods that are shared between REST and Realtime clients
/// (time, stats, request, etc.).
abstract class BaseClientImpl {
  BaseClientImpl({
    required ClientOptions options,
    http.Client? httpClient,
  }) : _options = options {
    _validateOptions(options);

    rawHttpClient = httpClient ?? http.Client();

    ablyHttpClient = AblyHttpClient(
      options: options,
      httpClient: rawHttpClient,
    );

    authImpl = AuthImpl(
      options: options,
      httpClient: ablyHttpClient,
      rawHttpClient: rawHttpClient,
    );

    // Wire up auth header provider
    ablyHttpClient.authHeaderProvider = authImpl.getAuthorizationHeader;

    // Wire up token renewer for auto-retry on token errors (RSA4b4)
    if (_hasTokenRenewalMechanism(options)) {
      ablyHttpClient.tokenRenewer = () => authImpl.authorize();
    }
  }

  final ClientOptions _options;

  /// The raw HTTP client, available to subclasses for dependency injection.
  @protected
  late final http.Client rawHttpClient;

  /// The Ably HTTP client used for REST API requests.
  @protected
  late final AblyHttpClient ablyHttpClient;

  /// The auth implementation.
  @protected
  late final AuthImpl authImpl;

  ClientOptions get options => _options;
  Auth get auth => authImpl;
  String? get clientId => authImpl.clientId;

  /// Returns true if there's a mechanism to renew tokens.
  /// Token renewal requires either a key, authCallback, or authUrl.
  /// A static token alone cannot be renewed.
  bool _hasTokenRenewalMechanism(ClientOptions options) {
    return options.key != null ||
        options.authCallback != null ||
        options.authUrl != null;
  }

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
            message:
                'Invalid API key format. Expected format: keyName:keySecret',
            code: 40101,
            statusCode: 401,
          ),
        );
      }

      // RSC18: Reject Basic auth over non-TLS connection
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

  /// Gets the current server time.
  ///
  /// Spec: RSC16, RTC6a
  Future<DateTime> time() async {
    // RSC16: time() does not require authentication
    final response = await ablyHttpClient.request(
      'GET',
      '/time',
      authenticated: false,
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

  /// Gets application statistics.
  ///
  /// Returns a [PaginatedResult] containing [Stats] objects.
  ///
  /// Spec: RSC6, RTC5a
  Future<PaginatedResult<Stats>> stats({
    DateTime? start,
    DateTime? end,
    StatsDirection? direction,
    int? limit,
    StatsUnit? unit,
  }) async {
    final queryParams = <String, String>{};
    if (start != null) {
      queryParams['start'] = start.millisecondsSinceEpoch.toString();
    }
    if (end != null) {
      queryParams['end'] = end.millisecondsSinceEpoch.toString();
    }
    if (direction != null) {
      queryParams['direction'] = direction.name;
    }
    if (limit != null) {
      queryParams['limit'] = limit.toString();
    }
    if (unit != null) {
      queryParams['unit'] = unit.name;
    }

    final response = await ablyHttpClient.request(
      'GET',
      '/stats',
      queryParams: queryParams.isNotEmpty ? queryParams : null,
      authenticated: true,
    );

    final items = _parseStats(response.body);

    return PaginatedResultImpl.fromResponse<Stats>(
      response: response,
      items: items,
      fetcher: (url) => _fetchStatsPage(url),
    );
  }

  Future<PaginatedResult<Stats>> _fetchStatsPage(String url) async {
    final uri = Uri.parse(url);

    final response = await ablyHttpClient.request(
      'GET',
      uri.path,
      queryParams: uri.queryParameters.isNotEmpty
          ? Map<String, String>.from(uri.queryParameters)
          : null,
      authenticated: true,
    );

    final items = _parseStats(response.body);

    return PaginatedResultImpl.fromResponse<Stats>(
      response: response,
      items: items,
      fetcher: (nextUrl) => _fetchStatsPage(nextUrl),
    );
  }

  List<Stats> _parseStats(dynamic body) {
    if (body == null) return [];
    if (body is! List) return [];
    return body.cast<Map<String, dynamic>>().map(Stats.fromMap).toList();
  }
}
