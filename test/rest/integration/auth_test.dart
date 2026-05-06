@Tags(['integration'])
library;

import 'package:test/test.dart';
import 'package:ably_dart/ably_dart.dart';

import '../../helpers/jwt_helper.dart';
import '../../helpers/test_app_helper.dart';
import '../../helpers/test_channel_name.dart';

void main() {
  late TestApp testApp;

  setUpAll(() async {
    testApp = await TestApp.provision();
  });

  tearDownAll(() async {
    await testApp.delete();
  });

  // ---------------------------------------------------------------------------
  // RSA4 — Basic auth with API key
  // ---------------------------------------------------------------------------
  group('RSA4 - Basic auth', () {
    // UTS: rest/integration/RSA4/basic-auth-key-0
    test('RSA4 - basic auth with API key succeeds', () async {
      final client = Rest(
        options: ClientOptions(
          key: testApp.keys[0].keyStr,
          endpoint: 'sandbox',
          useBinaryProtocol: false,
        ),
      );
      addTearDown(client.close);

      final channelName = testChannelName('rsa4-basic');
      final response = await client.request('GET', '/channels/$channelName');
      expect(response.statusCode, inInclusiveRange(200, 299));
    });
  });

  // ---------------------------------------------------------------------------
  // RSA8 — JWT token auth
  // ---------------------------------------------------------------------------
  group('RSA8 - JWT token auth', () {
    // UTS: rest/integration/RSA8/token-auth-jwt-0
    test('RSA8 JWT - pre-generated JWT succeeds', () async {
      final jwt = JwtHelper.generateToken(
        apiKey: testApp.keys[0].keyStr,
      );

      final client = Rest(
        options: ClientOptions(
          token: jwt,
          endpoint: 'sandbox',
          useBinaryProtocol: false,
        ),
      );
      addTearDown(client.close);

      final channelName = testChannelName('rsa8-jwt');
      final response = await client.request('GET', '/channels/$channelName');
      expect(response.statusCode, inInclusiveRange(200, 299));
    });

    // UTS: rest/integration/RSA8/token-auth-native-1
    test('RSA8 native token - requestToken then use token string', () async {
      // Obtain a native Ably token using a key-authenticated client.
      final keyClient = Rest(
        options: ClientOptions(
          key: testApp.keys[0].keyStr,
          endpoint: 'sandbox',
          useBinaryProtocol: false,
        ),
      );
      addTearDown(keyClient.close);

      final tokenDetails = await keyClient.auth.requestToken();
      expect(tokenDetails.token, isNotNull);

      // Create a new client using only the token string.
      final tokenClient = Rest(
        options: ClientOptions(
          token: tokenDetails.token,
          endpoint: 'sandbox',
          useBinaryProtocol: false,
        ),
      );
      addTearDown(tokenClient.close);

      final channelName = testChannelName('rsa8-native');
      final response =
          await tokenClient.request('GET', '/channels/$channelName');
      expect(response.statusCode, inInclusiveRange(200, 299));
    });

    // UTS: rest/integration/RSA8/auth-callback-jwt-3
    test('RSA8 authCallback returning TokenRequest succeeds', () async {
      final keyClient = Rest(
        options: ClientOptions(
          key: testApp.keys[0].keyStr,
          endpoint: 'sandbox',
          useBinaryProtocol: false,
        ),
      );
      addTearDown(keyClient.close);

      final client = Rest(
        options: ClientOptions(
          authCallback: (params) async {
            return keyClient.auth.createTokenRequest();
          },
          endpoint: 'sandbox',
          useBinaryProtocol: false,
        ),
      );
      addTearDown(client.close);

      final channelName = testChannelName('rsa8-tr');
      final response = await client.request('GET', '/channels/$channelName');
      expect(response.statusCode, inInclusiveRange(200, 299));
    });

    // UTS: rest/integration/RSA8/auth-callback-token-request-2
    test('RSA8 authCallback returning JWT string succeeds', () async {
      final apiKey = testApp.keys[0].keyStr;

      final client = Rest(
        options: ClientOptions(
          authCallback: (params) async {
            return JwtHelper.generateToken(apiKey: apiKey);
          },
          endpoint: 'sandbox',
          useBinaryProtocol: false,
        ),
      );
      addTearDown(client.close);

      final channelName = testChannelName('rsa8-jwt-cb');
      final response = await client.request('GET', '/channels/$channelName');
      expect(response.statusCode, inInclusiveRange(200, 299));
    });
  });

  // ---------------------------------------------------------------------------
  // RSA4 — Invalid credentials
  // ---------------------------------------------------------------------------
  group('RSA4 - Invalid credentials', () {
    // UTS: rest/integration/RSA4/invalid-credentials-rejected-1
    test('RSA4 - invalid API key returns 401 / error code 40400', () async {
      final client = Rest(
        options: ClientOptions(
          key: '${testApp.appId}.invalidKey:invalidSecret',
          endpoint: 'sandbox',
          useBinaryProtocol: false,
        ),
      );
      addTearDown(client.close);

      final channelName = testChannelName('rsa4-invalid');
      try {
        await client.request('GET', '/channels/$channelName');
        fail('Expected AblyException to be thrown');
      } on AblyException catch (e) {
        expect(
          e.statusCode,
          equals(401),
          reason: 'Expected HTTP 401, got ${e.statusCode}',
        );
        // The server returns error code 40400 (key/app not found)
        expect(
          e.code,
          equals(40400),
          reason: 'Expected Ably error code 40400, got ${e.code}',
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  // RSC10 — Expired JWT renewal
  // ---------------------------------------------------------------------------
  group('RSC10 - Expired JWT renewal', () {
    test(
        'RSC10 - authCallback called twice when first JWT is expired, '
        'request ultimately succeeds', () async {
      final apiKey = testApp.keys[0].keyStr;
      var callCount = 0;

      final client = Rest(
        options: ClientOptions(
          authCallback: (params) async {
            callCount++;
            if (callCount == 1) {
              // Return an already-expired JWT
              return JwtHelper.generateToken(
                apiKey: apiKey,
                expiresAt: DateTime.now().subtract(const Duration(seconds: 5)),
              );
            }
            // Second call: return a valid JWT
            return JwtHelper.generateToken(apiKey: apiKey);
          },
          endpoint: 'sandbox',
          useBinaryProtocol: false,
        ),
      );
      addTearDown(client.close);

      final channelName = testChannelName('rsc10-renewal');
      final response = await client.request('GET', '/channels/$channelName');
      expect(response.statusCode, inInclusiveRange(200, 299));
      expect(
        callCount,
        equals(2),
        reason: 'authCallback should be called twice (expired + renewal)',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // RSA8 — Capability restriction
  // ---------------------------------------------------------------------------
  group('RSA8 - Capability restriction', () {
    test(
        'RSA8 capability - publish to allowed channel succeeds, '
        'publish to denied channel fails with 40160', () async {
      final apiKey = testApp.keys[0].keyStr;
      final allowedChannel = testChannelName('allowed');
      final deniedChannel = testChannelName('denied');

      // JWT restricted to publish on allowedChannel only
      final restrictedJwt = JwtHelper.generateToken(
        apiKey: apiKey,
        capability: '{"$allowedChannel":["publish"]}',
      );

      final client = Rest(
        options: ClientOptions(
          token: restrictedJwt,
          endpoint: 'sandbox',
          useBinaryProtocol: false,
        ),
      );
      addTearDown(client.close);

      // Publish to allowed channel should succeed
      final result = await client.channels
          .get(allowedChannel)
          .publish(name: 'test', data: 'hello');
      expect(result.serials, isNotEmpty);

      // Publish to denied channel should fail with capability error
      try {
        await client.channels
            .get(deniedChannel)
            .publish(name: 'test', data: 'hello');
        fail('Expected AblyException to be thrown for denied channel');
      } on AblyException catch (e) {
        expect(
          e.code,
          equals(40160),
          reason: 'Expected Ably capability error 40160, got ${e.code}',
        );
      }
    });
  });
}
