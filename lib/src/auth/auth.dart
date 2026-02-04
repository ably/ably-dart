import 'auth_options.dart';
import 'token_details.dart';
import 'token_params.dart';
import 'token_request.dart';

/// Describes the authentication method used by the client.
///
/// Spec: RSA4
enum AuthMethod {
  /// Basic authentication using the API key.
  basic,

  /// Token authentication using a token or token callback.
  token,
}

/// Provides authentication operations for the Ably client.
///
/// Spec: RSA
abstract class Auth {
  /// The clientId associated with this client.
  ///
  /// May be null if not identified.
  ///
  /// Spec: RSA7
  String? get clientId;

  /// The current authentication method.
  ///
  /// Spec: RSA4
  AuthMethod get method;

  /// The current token details, if any.
  ///
  /// Returns a [TokenDetails] representing the token currently in use by
  /// the library. Returns null if there is no current token (e.g., when
  /// using basic auth or before any token has been obtained).
  ///
  /// Spec: RSA16
  TokenDetails? get tokenDetails;

  /// Obtains a new token, replacing any existing token.
  ///
  /// If [authOptions] is provided, it replaces the stored auth options
  /// for subsequent token renewals.
  ///
  /// If [tokenParams] is provided, it specifies the token parameters.
  ///
  /// Spec: RSA10
  Future<TokenDetails> authorize({
    AuthOptions? authOptions,
    TokenParams? tokenParams,
  });

  /// Returns the current valid token, or obtains a new one if needed.
  ///
  /// Unlike [authorize], this method returns the cached token if it exists
  /// and has not expired, avoiding unnecessary token requests.
  ///
  /// This is used internally for connection authentication where we want
  /// to reuse valid tokens across reconnection attempts.
  Future<TokenDetails> getValidToken();

  /// Creates a signed [TokenRequest] that can be used to obtain a token.
  ///
  /// This method requires the client to be configured with an API key.
  ///
  /// Spec: RSA9
  Future<TokenRequest> createTokenRequest({
    AuthOptions? authOptions,
    TokenParams? tokenParams,
  });

  /// Requests a new token from the Ably service.
  ///
  /// This method does not update the client's stored token.
  ///
  /// Spec: RSA8
  Future<TokenDetails> requestToken({
    AuthOptions? authOptions,
    TokenParams? tokenParams,
  });
}
