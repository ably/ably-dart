import 'dart:async';

import '../auth/auth.dart';
import '../auth/auth_options.dart';
import '../auth/token_details.dart';
import '../auth/token_params.dart';
import '../auth/token_request.dart';
import '../auth/token_revocation.dart';
import '../realtime/connection.dart';
import 'auth_impl.dart';

/// Auth wrapper for Realtime clients that adds in-band reauthorization.
///
/// Delegates all methods to [AuthImpl], overriding only [authorize] with
/// RTC8 logic: when the connection is CONNECTED, sends an AUTH protocol
/// message instead of disconnecting.
///
/// Multiple concurrent [authorize] calls are serialized so that only one
/// auth operation is in flight to the server at a time.
///
/// Spec: RTC8
class RealtimeAuth implements Auth {
  RealtimeAuth({
    required AuthImpl authImpl,
    required Connection connection,
  })  : _authImpl = authImpl,
        _connection = connection;

  final AuthImpl _authImpl;
  final Connection _connection;

  /// Serialization guard — each authorize waits for the previous to complete.
  Future<void> _authGuard = Future.value();

  @override
  String? get clientId => _authImpl.clientId;

  @override
  AuthMethod get method => _authImpl.method;

  @override
  TokenDetails? get tokenDetails => _authImpl.tokenDetails;

  @override
  Future<TokenDetails?> authorize({
    AuthOptions? authOptions,
    TokenParams? tokenParams,
  }) async {
    // Serialize: wait for any prior authorize to finish
    final previousGuard = _authGuard;
    final completer = Completer<void>();
    _authGuard = completer.future;

    // Don't block on prior failure
    await previousGuard.catchError((_) {});

    try {
      final tokenDetails = await _authImpl.authorize(
        authOptions: authOptions,
        tokenParams: tokenParams,
      );
      if (tokenDetails != null) {
        await _connection.reauthorize(tokenDetails);
      }
      return tokenDetails;
    } finally {
      // Always complete the guard successfully — it's just a serialization
      // signal. The actual error is propagated to the caller via the future.
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  @override
  Future<TokenDetails> getValidToken() => _authImpl.getValidToken();

  @override
  Future<TokenRequest> createTokenRequest({
    AuthOptions? authOptions,
    TokenParams? tokenParams,
  }) =>
      _authImpl.createTokenRequest(
        authOptions: authOptions,
        tokenParams: tokenParams,
      );

  @override
  Future<TokenDetails> requestToken({
    AuthOptions? authOptions,
    TokenParams? tokenParams,
  }) =>
      _authImpl.requestToken(
        authOptions: authOptions,
        tokenParams: tokenParams,
      );

  @override
  Future<TokenRevocationResponse> revokeTokens(
    List<TokenRevocationTargetSpecifier> specifiers, {
    RevokeTokensOptions? options,
  }) =>
      _authImpl.revokeTokens(specifiers, options: options);
}
