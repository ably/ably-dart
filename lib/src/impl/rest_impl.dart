import 'package:http/http.dart' as http;

import '../auth/auth.dart';
import '../auth/client_options.dart';
import '../channels/channels.dart';
import '../client/rest.dart';
import '../error/ably_exception.dart';
import '../error/error_info.dart';
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
  Future<void> close() async {
    _httpClient.close();
  }
}
