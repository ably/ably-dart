import 'package:meta/meta.dart';

import 'token_details.dart';
import 'token_params.dart';

/// Callback signature for obtaining authentication tokens.
///
/// The callback receives [TokenParams] and should return one of:
/// - A [TokenDetails] object
/// - A [TokenRequest] object
/// - A raw token string
/// - An Ably JWT string
typedef AuthCallback = Future<Object> Function(TokenParams params);

/// Authentication options for the Ably client.
///
/// Spec: AO
@immutable
class AuthOptions {
  /// Creates an AuthOptions instance.
  const AuthOptions({
    this.key,
    this.authUrl,
    this.authMethod = 'GET',
    this.authHeaders,
    this.authParams,
    this.authCallback,
    this.tokenDetails,
    this.token,
    this.queryTime = false,
    this.useTokenAuth,
  });

  /// The full API key string.
  ///
  /// When provided without other auth methods, Basic authentication is used.
  final String? key;

  /// A URL to be used to GET or POST a set of token request params
  /// to obtain a signed token request or token.
  final String? authUrl;

  /// The HTTP method to use when contacting the authUrl.
  ///
  /// Defaults to 'GET'.
  final String? authMethod;

  /// Headers to be included in the authUrl request.
  final Map<String, String>? authHeaders;

  /// Parameters to be included in the authUrl request.
  final Map<String, String>? authParams;

  /// A callback to be invoked to obtain a token.
  final AuthCallback? authCallback;

  /// A pre-obtained token details object.
  final TokenDetails? tokenDetails;

  /// A pre-obtained token string.
  final String? token;

  /// Whether to query the Ably server for the current time.
  ///
  /// When true, the SDK queries Ably for the current time when
  /// issuing a token request. Useful when local time is unreliable.
  final bool? queryTime;

  /// Force token authentication even when a key is available.
  final bool? useTokenAuth;

  /// Creates a copy of this AuthOptions with the given fields replaced.
  AuthOptions copyWith({
    String? key,
    String? authUrl,
    String? authMethod,
    Map<String, String>? authHeaders,
    Map<String, String>? authParams,
    AuthCallback? authCallback,
    TokenDetails? tokenDetails,
    String? token,
    bool? queryTime,
    bool? useTokenAuth,
  }) {
    return AuthOptions(
      key: key ?? this.key,
      authUrl: authUrl ?? this.authUrl,
      authMethod: authMethod ?? this.authMethod,
      authHeaders: authHeaders ?? this.authHeaders,
      authParams: authParams ?? this.authParams,
      authCallback: authCallback ?? this.authCallback,
      tokenDetails: tokenDetails ?? this.tokenDetails,
      token: token ?? this.token,
      queryTime: queryTime ?? this.queryTime,
      useTokenAuth: useTokenAuth ?? this.useTokenAuth,
    );
  }

  @override
  String toString() {
    final parts = <String>[];
    if (key != null) parts.add('key=${key!.split(':').first}:***');
    if (authUrl != null) parts.add('authUrl=$authUrl');
    if (authCallback != null) parts.add('authCallback=<function>');
    if (tokenDetails != null) parts.add('tokenDetails=$tokenDetails');
    if (token != null) parts.add('token=${token!.substring(0, 10)}...');
    return 'AuthOptions(${parts.join(', ')})';
  }
}
