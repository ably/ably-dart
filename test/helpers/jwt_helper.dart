import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// Helper for generating Ably-compatible JWT tokens in integration tests.
///
/// Ably JWTs use the following structure:
/// - Header: {"typ": "JWT", "alg": "HS256", "kid": keyName}
/// - Payload: standard claims (iat, exp) + Ably claims (x-ably-capability, x-ably-clientId)
/// - Signed with the key secret using HMAC-SHA256
class JwtHelper {
  /// Generates an Ably-compatible JWT token.
  ///
  /// [apiKey] is the full Ably API key (keyName:keySecret).
  /// [ttl] is the token time-to-live in milliseconds (default: 1 hour).
  /// [capability] is the JSON-encoded capability (default: full access).
  /// [clientId] is an optional clientId to bind to the token.
  /// [expiresAt] overrides the expiry time (used for expired token tests).
  /// [issuedAt] overrides the issued-at time (use with [expiresAt] to create
  /// tokens with a positive TTL that are already expired).
  static String generateToken({
    required String apiKey,
    int ttl = 3600000,
    String capability = '{"*":["*"]}',
    String? clientId,
    DateTime? expiresAt,
    DateTime? issuedAt,
  }) {
    final parts = apiKey.split(':');
    if (parts.length != 2) {
      throw ArgumentError('Invalid API key format. Expected keyName:keySecret');
    }
    final keyName = parts[0];
    final keySecret = parts[1];

    final now = issuedAt ?? DateTime.now();
    final iat = now.millisecondsSinceEpoch ~/ 1000;
    final exp = expiresAt != null
        ? expiresAt.millisecondsSinceEpoch ~/ 1000
        : iat + (ttl ~/ 1000);

    final claims = <String, dynamic>{
      'iat': iat,
      'exp': exp,
      'x-ably-capability': capability,
      if (clientId != null) 'x-ably-clientId': clientId,
    };

    final jwt = JWT(
      claims,
      header: {'kid': keyName},
    );

    return jwt.sign(
      SecretKey(keySecret),
    );
  }

  /// Extracts the key name from an API key string.
  static String extractKeyName(String apiKey) => apiKey.split(':')[0];

  /// Extracts the key secret from an API key string.
  static String extractKeySecret(String apiKey) => apiKey.split(':')[1];
}
