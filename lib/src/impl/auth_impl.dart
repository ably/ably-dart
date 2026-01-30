import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../auth/auth.dart';
import '../auth/auth_options.dart';
import '../auth/client_options.dart';
import '../auth/token_details.dart';
import '../auth/token_params.dart';
import '../auth/token_request.dart';
import '../error/ably_exception.dart';
import '../error/error_info.dart';
import 'http/http_client.dart';

/// Implementation of the Auth interface.
class AuthImpl implements Auth {
  AuthImpl({
    required ClientOptions options,
    required AblyHttpClient httpClient,
    http.Client? rawHttpClient,
  })  : _options = options,
        _httpClient = httpClient,
        _rawHttpClient = rawHttpClient ?? http.Client() {
    _initialize();
  }

  final ClientOptions _options;
  final AblyHttpClient _httpClient;
  final http.Client _rawHttpClient;

  TokenDetails? _currentToken;
  AuthOptions? _storedAuthOptions;
  TokenParams? _storedTokenParams;

  void _initialize() {
    // Initialize with any token provided in options
    if (_options.tokenDetails != null) {
      _currentToken = _options.tokenDetails;
    } else if (_options.token != null) {
      _currentToken = TokenDetails(token: _options.token);
    }
  }

  @override
  String? get clientId {
    // Return clientId from options, current token, or token params
    return _options.clientId ??
        _currentToken?.clientId ??
        _storedTokenParams?.clientId;
  }

  @override
  AuthMethod get method {
    // Determine auth method based on options (RSA4)
    if (_shouldUseTokenAuth()) {
      return AuthMethod.token;
    }
    return AuthMethod.basic;
  }

  bool _shouldUseTokenAuth() {
    // RSA4: Use token auth if:
    // - useTokenAuth is explicitly true
    // - authCallback is set
    // - authUrl is set
    // - clientId is set (RSA4b - can't use basic auth with clientId)
    // - token or tokenDetails is set
    if (_options.useTokenAuth == true) return true;
    if (_options.authCallback != null) return true;
    if (_options.authUrl != null) return true;
    if (_options.clientId != null) return true;
    if (_options.token != null) return true;
    if (_options.tokenDetails != null) return true;
    return false;
  }

  /// Gets the authorization header for HTTP requests.
  Future<String> getAuthorizationHeader() async {
    if (method == AuthMethod.basic) {
      return _getBasicAuthHeader();
    }
    return _getTokenAuthHeader();
  }

  String _getBasicAuthHeader() {
    final key = _options.key;
    if (key == null) {
      throw const AblyException(
        message: 'API key required for Basic authentication',
        errorInfo: ErrorInfo(
          message: 'API key required for Basic authentication',
          code: 40101,
          statusCode: 401,
        ),
      );
    }
    return 'Basic ${base64.encode(utf8.encode(key))}';
  }

  Future<String> _getTokenAuthHeader() async {
    // Ensure we have a valid token
    if (_currentToken == null || _currentToken!.isExpired) {
      await authorize();
    }

    final token = _currentToken?.token;
    if (token == null) {
      throw const AblyException(
        message: 'No token available',
        errorInfo: ErrorInfo(
          message: 'No token available',
          code: 40101,
          statusCode: 401,
        ),
      );
    }

    return 'Bearer $token';
  }

  @override
  Future<TokenDetails> authorize({
    AuthOptions? authOptions,
    TokenParams? tokenParams,
  }) async {
    // RSA10: Authorize and store token
    // If authOptions provided, replace stored options
    if (authOptions != null) {
      _storedAuthOptions = authOptions;
    }

    // Merge token params
    final effectiveParams = _mergeTokenParams(tokenParams);

    // Request a new token
    _currentToken = await requestToken(
      authOptions: authOptions ?? _storedAuthOptions,
      tokenParams: effectiveParams,
    );

    return _currentToken!;
  }

  @override
  Future<TokenRequest> createTokenRequest({
    AuthOptions? authOptions,
    TokenParams? tokenParams,
  }) async {
    // RSA9: Create a signed token request
    final effectiveOptions = authOptions ?? _storedAuthOptions ?? _options;
    final key = effectiveOptions.key ?? _options.key;

    if (key == null) {
      throw const AblyException(
        message: 'API key required to create token request',
        errorInfo: ErrorInfo(
          message: 'API key required to create token request',
          code: 40101,
          statusCode: 401,
        ),
      );
    }

    // Parse key into keyName and keySecret
    final keyParts = key.split(':');
    if (keyParts.length != 2) {
      throw const AblyException(
        message: 'Invalid API key format',
        errorInfo: ErrorInfo(
          message: 'Invalid API key format',
          code: 40101,
          statusCode: 401,
        ),
      );
    }
    final keyName = keyParts[0];
    final keySecret = keyParts[1];

    // Merge token params
    final effectiveParams = _mergeTokenParams(tokenParams);

    // Generate nonce if not provided (RSA9c)
    final nonce = effectiveParams.nonce ?? _generateNonce();

    // Get timestamp
    int timestamp;
    if (effectiveParams.timestamp != null) {
      timestamp = effectiveParams.timestamp!;
    } else if (effectiveOptions.queryTime == true || _options.queryTime == true) {
      // Query server time
      final serverTime = await _queryServerTime();
      timestamp = serverTime.millisecondsSinceEpoch;
    } else {
      timestamp = DateTime.now().millisecondsSinceEpoch;
    }

    // Build the token request
    final ttl = effectiveParams.ttl ?? 3600000; // Default 1 hour
    final capability = effectiveParams.capability ?? '{"*":["*"]}';
    final requestClientId = effectiveParams.clientId ?? _options.clientId;

    // Create the signing text (RSA9g)
    final signText = [
      keyName,
      ttl.toString(),
      capability,
      requestClientId ?? '',
      timestamp.toString(),
      nonce,
    ].join('\n');

    // Sign with HMAC-SHA256 (RSA9h)
    final mac = _sign(signText, keySecret);

    return TokenRequest(
      keyName: keyName,
      nonce: nonce,
      mac: mac,
      capability: capability,
      clientId: requestClientId,
      timestamp: timestamp,
      ttl: ttl,
    );
  }

  @override
  Future<TokenDetails> requestToken({
    AuthOptions? authOptions,
    TokenParams? tokenParams,
  }) async {
    // RSA8: Request a token without updating stored token
    final effectiveOptions = authOptions ?? _storedAuthOptions ?? _options;
    final effectiveParams = _mergeTokenParams(tokenParams);

    // Try different token acquisition methods in order
    // 1. authCallback
    if (effectiveOptions.authCallback != null) {
      return _requestTokenFromCallback(effectiveOptions, effectiveParams);
    }

    // 2. authUrl
    if (effectiveOptions.authUrl != null) {
      return _requestTokenFromUrl(effectiveOptions, effectiveParams);
    }

    // 3. Direct token request using API key
    if (effectiveOptions.key != null || _options.key != null) {
      return _requestTokenFromAbly(effectiveOptions, effectiveParams);
    }

    throw const AblyException(
      message: 'No authentication method available',
      errorInfo: ErrorInfo(
        message: 'No authentication method available',
        code: 40101,
        statusCode: 401,
      ),
    );
  }

  Future<TokenDetails> _requestTokenFromCallback(
    AuthOptions options,
    TokenParams params,
  ) async {
    final result = await options.authCallback!(params);

    if (result is TokenDetails) {
      return result;
    }

    if (result is TokenRequest) {
      // Exchange token request for token
      return _exchangeTokenRequest(result);
    }

    if (result is String) {
      // Could be a raw token or JWT
      return TokenDetails(token: result);
    }

    if (result is Map<String, dynamic>) {
      // Could be TokenDetails or TokenRequest as JSON
      if (result.containsKey('mac')) {
        return _exchangeTokenRequest(TokenRequest.fromMap(result));
      }
      return TokenDetails.fromMap(result);
    }

    throw AblyException(
      message: 'Invalid authCallback result: ${result.runtimeType}',
      errorInfo: ErrorInfo(
        message: 'Invalid authCallback result: ${result.runtimeType}',
        code: 40170,
        statusCode: 401,
      ),
    );
  }

  Future<TokenDetails> _requestTokenFromUrl(
    AuthOptions options,
    TokenParams params,
  ) async {
    // Build request URL with params
    var uri = Uri.parse(options.authUrl!);

    final queryParams = Map<String, String>.from(options.authParams ?? {});
    queryParams.addAll(params.toQueryParams());

    final method = (options.authMethod ?? 'GET').toUpperCase();

    // Build headers
    final headers = Map<String, String>.from(options.authHeaders ?? {});

    http.Response response;
    if (method == 'GET') {
      uri = uri.replace(
        queryParameters: {...uri.queryParameters, ...queryParams},
      );
      response = await _rawHttpClient.get(uri, headers: headers);
    } else {
      headers['Content-Type'] = 'application/x-www-form-urlencoded';
      response = await _rawHttpClient.post(
        uri,
        headers: headers,
        body: queryParams,
      );
    }

    // Parse response
    dynamic body;
    // HTTP headers are case-insensitive, check both variations
    final contentType = response.headers['content-type'] ??
        response.headers['Content-Type'] ??
        '';
    if (contentType.contains('application/json')) {
      body = json.decode(response.body);
    } else {
      // Try to parse as JSON anyway if it looks like JSON
      final trimmed = response.body.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          body = json.decode(response.body);
        } catch (_) {
          body = response.body;
        }
      } else {
        body = response.body;
      }
    }

    if (body is Map<String, dynamic>) {
      if (body.containsKey('mac')) {
        // It's a TokenRequest
        return _exchangeTokenRequest(TokenRequest.fromMap(body));
      }
      // It's TokenDetails
      return TokenDetails.fromMap(body);
    }

    if (body is String) {
      // Raw token string
      return TokenDetails(token: body);
    }

    throw AblyException(
      message: 'Invalid authUrl response',
      errorInfo: ErrorInfo(
        message: 'Invalid authUrl response: ${body.runtimeType}',
        code: 40170,
        statusCode: 401,
      ),
    );
  }

  Future<TokenDetails> _requestTokenFromAbly(
    AuthOptions options,
    TokenParams params,
  ) async {
    // Create a signed token request
    final tokenRequest = await createTokenRequest(
      authOptions: options,
      tokenParams: params,
    );

    return _exchangeTokenRequest(tokenRequest);
  }

  Future<TokenDetails> _exchangeTokenRequest(TokenRequest tokenRequest) async {
    // POST the token request to Ably
    final response = await _httpClient.request(
      'POST',
      '/keys/${tokenRequest.keyName}/requestToken',
      body: tokenRequest.toMap(),
      authenticated: false, // Token requests are self-authenticating
    );

    return TokenDetails.fromMap(response.body as Map<String, dynamic>);
  }

  TokenParams _mergeTokenParams(TokenParams? params) {
    // Merge with stored params and default params
    final defaults = _options.defaultTokenParams;
    final stored = _storedTokenParams;

    return TokenParams(
      capability: params?.capability ?? stored?.capability ?? defaults?.capability,
      clientId: params?.clientId ?? stored?.clientId ?? defaults?.clientId ?? _options.clientId,
      nonce: params?.nonce ?? stored?.nonce ?? defaults?.nonce,
      timestamp: params?.timestamp ?? stored?.timestamp ?? defaults?.timestamp,
      ttl: params?.ttl ?? stored?.ttl ?? defaults?.ttl,
    );
  }

  Future<DateTime> _queryServerTime() async {
    final response = await _httpClient.request(
      'GET',
      '/time',
      authenticated: false,
    );

    final timestamps = response.body as List<dynamic>;
    return DateTime.fromMillisecondsSinceEpoch(timestamps[0] as int);
  }

  String _generateNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _sign(String text, String secret) {
    final key = utf8.encode(secret);
    final bytes = utf8.encode(text);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return base64.encode(digest.bytes);
  }
}
