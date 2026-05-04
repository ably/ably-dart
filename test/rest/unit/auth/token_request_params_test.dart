import 'package:ably_dart/ably_dart.dart';
import 'package:test/test.dart';

/// Token Request Parameter Defaults Tests
///
/// Spec points: RSA5, RSA6, RSA9
///
/// Tests the handling of `ttl` and `capability` parameters in
/// `createTokenRequest()`. When not specified by the user, these fields
/// must be null in the TokenRequest rather than defaulted client-side.
///
/// Spec: uts/test/rest/unit/auth/token_request_params.md
void main() {
  group('RSA5 - TTL handling in createTokenRequest', () {
    test('RSA5 - TTL is null when not specified', () async {
      final client = Rest.fromKey('appId.keyId:keySecret');

      final tokenRequest = await client.auth.createTokenRequest();

      // TTL should be null (not zero, not a default like 3600000)
      expect(tokenRequest.ttl, isNull);
    });

    test('RSA5b - explicit TTL is preserved', () async {
      final client = Rest.fromKey('appId.keyId:keySecret');

      final tokenRequest = await client.auth.createTokenRequest(
        tokenParams: const TokenParams(ttl: 7200000), // 2 hours
      );

      expect(tokenRequest.ttl, equals(7200000));
    });

    test('RSA5c - TTL from defaultTokenParams is used', () async {
      final client = Rest(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          defaultTokenParams: const TokenParams(ttl: 1800000), // 30 minutes
        ),
      );

      final tokenRequest = await client.auth.createTokenRequest();

      expect(tokenRequest.ttl, equals(1800000));
    });

    test('RSA5d - explicit TTL overrides defaultTokenParams', () async {
      final client = Rest(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          defaultTokenParams: const TokenParams(ttl: 1800000), // 30 minutes
        ),
      );

      final tokenRequest = await client.auth.createTokenRequest(
        tokenParams: const TokenParams(ttl: 600000), // 10 minutes
      );

      expect(tokenRequest.ttl, equals(600000));
    });
  });

  group('RSA6 - Capability handling in createTokenRequest', () {
    test('RSA6 - capability is null when not specified', () async {
      final client = Rest.fromKey('appId.keyId:keySecret');

      final tokenRequest = await client.auth.createTokenRequest();

      // Capability should be null (not a default like '{"*":["*"]}')
      expect(tokenRequest.capability, isNull);
    });

    test('RSA6b - explicit capability is preserved', () async {
      final client = Rest.fromKey('appId.keyId:keySecret');

      final tokenRequest = await client.auth.createTokenRequest(
        tokenParams: const TokenParams(
          capability: '{"channel-a":["publish","subscribe"]}',
        ),
      );

      expect(
        tokenRequest.capability,
        equals('{"channel-a":["publish","subscribe"]}'),
      );
    });

    test('RSA6c - capability from defaultTokenParams is used', () async {
      final client = Rest(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          defaultTokenParams: const TokenParams(
            capability: '{"*":["subscribe"]}',
          ),
        ),
      );

      final tokenRequest = await client.auth.createTokenRequest();

      expect(tokenRequest.capability, equals('{"*":["subscribe"]}'));
    });

    test('RSA6d - explicit capability overrides defaultTokenParams', () async {
      final client = Rest(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          defaultTokenParams: const TokenParams(
            capability: '{"*":["subscribe"]}',
          ),
        ),
      );

      final tokenRequest = await client.auth.createTokenRequest(
        tokenParams: const TokenParams(
          capability: '{"channel-x":["publish"]}',
        ),
      );

      expect(tokenRequest.capability, equals('{"channel-x":["publish"]}'));
    });
  });
}
