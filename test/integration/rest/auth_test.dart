import 'package:test/test.dart';
import 'package:ably_dart/ably_dart.dart';

import '../../helpers/jwt_helper.dart';
import '../../helpers/test_app_helper.dart';

/// Integration tests for REST auth.
///
/// These tests run against the Ably Sandbox environment and verify
/// authentication using API keys, JWTs, native tokens, and authCallbacks.
///
/// Spec: uts/test/rest/integration/auth.md
void main() {
  late TestApp testApp;
  late String apiKey;

  setUpAll(() async {
    testApp = await TestApp.provision();
    apiKey = testApp.keys[0].keyStr;
    print('Provisioned test app: ${testApp.appId}');
  });

  tearDownAll(() async {
    await testApp.delete();
    print('Deleted test app: ${testApp.appId}');
  });

  group('RSA4 - Basic auth with API key', () {
    test('authenticates using API key via HTTP Basic Auth', () async {
      final channelName = 'test-RSA4-${DateTime.now().millisecondsSinceEpoch}';
      final client = Rest(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      final result = await client.request('GET', '/channels/$channelName');

      expect(result.statusCode, greaterThanOrEqualTo(200));
      expect(result.statusCode, lessThan(300));

      await client.close();
    });
  });

  group('RSA8 - Token auth with JWT', () {
    test('authenticates using a JWT token', () async {
      final jwt = JwtHelper.generateToken(apiKey: apiKey);

      final channelName =
          'test-RSA8-jwt-${DateTime.now().millisecondsSinceEpoch}';
      final client = Rest(
        options: ClientOptions(
          token: jwt,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      final result = await client.request('GET', '/channels/$channelName');

      expect(result.statusCode, greaterThanOrEqualTo(200));
      expect(result.statusCode, lessThan(300));

      await client.close();
    });
  });

  group('RSA8 - Token auth with native token', () {
    test('authenticates using a native token from requestToken()', () async {
      final keyClient = Rest(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      final tokenDetails = await keyClient.auth.requestToken();

      expect(tokenDetails.token, isA<String>());
      expect(tokenDetails.token, isNotEmpty);
      expect(tokenDetails.expires, isNotNull);
      expect(tokenDetails.expires!,
          greaterThan(DateTime.now().millisecondsSinceEpoch));

      final channelName =
          'test-RSA8-native-${DateTime.now().millisecondsSinceEpoch}';
      final tokenClient = Rest(
        options: ClientOptions(
          token: tokenDetails.token,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      final result = await tokenClient.request('GET', '/channels/$channelName');

      expect(result.statusCode, greaterThanOrEqualTo(200));
      expect(result.statusCode, lessThan(300));

      await keyClient.close();
      await tokenClient.close();
    });
  });

  group('RSA8 - authCallback with TokenRequest', () {
    test('authenticates via authCallback returning TokenRequest', () async {
      final tokenRequestClient = Rest(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      final client = Rest(
        options: ClientOptions(
          authCallback: (params) async {
            return await tokenRequestClient.auth.createTokenRequest(
              tokenParams: params,
            );
          },
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      final channelName =
          'test-RSA8-callback-${DateTime.now().millisecondsSinceEpoch}';
      final result = await client.request('GET', '/channels/$channelName');

      expect(result.statusCode, greaterThanOrEqualTo(200));
      expect(result.statusCode, lessThan(300));

      await client.close();
      await tokenRequestClient.close();
    });
  });

  group('RSA8 - authCallback with JWT', () {
    test('authenticates via authCallback returning JWT string', () async {
      final client = Rest(
        options: ClientOptions(
          authCallback: (params) async {
            return JwtHelper.generateToken(
              apiKey: apiKey,
              clientId: params.clientId,
            );
          },
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      final channelName =
          'test-RSA8-jwt-cb-${DateTime.now().millisecondsSinceEpoch}';
      final result = await client.request('GET', '/channels/$channelName');

      expect(result.statusCode, greaterThanOrEqualTo(200));
      expect(result.statusCode, lessThan(300));

      await client.close();
    });
  });

  group('RSA4 - Invalid credentials rejected', () {
    test('server rejects requests with invalid API key', () async {
      final channelName =
          'test-RSA4-invalid-${DateTime.now().millisecondsSinceEpoch}';
      // Use the real key name but a wrong secret
      final keyName = JwtHelper.extractKeyName(apiKey);
      final client = Rest(
        options: ClientOptions(
          key: '$keyName:wrongsecret',
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      await expectLater(
        () => client.request('GET', '/channels/$channelName'),
        throwsA(
          isA<AblyException>().having(
            (e) => e.errorInfo?.statusCode,
            'statusCode',
            equals(401),
          ),
        ),
      );

      await client.close();
    });
  });

  group('RSC10 - Token renewal with expired JWT', () {
    test('expired JWT triggers automatic token renewal via authCallback',
        () async {
      var callbackCount = 0;

      final client = Rest(
        options: ClientOptions(
          authCallback: (params) async {
            callbackCount++;
            if (callbackCount == 1) {
              // First call: return a short-lived JWT (2 seconds)
              return JwtHelper.generateToken(
                apiKey: apiKey,
                ttl: 2000,
              );
            } else {
              // Subsequent calls: return a valid JWT (1 hour)
              return JwtHelper.generateToken(apiKey: apiKey);
            }
          },
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      // First request — uses the short-lived token (still valid)
      final channelName =
          'test-RSC10-renewal-${DateTime.now().millisecondsSinceEpoch}';
      final result1 = await client.request('GET', '/channels/$channelName');
      expect(result1.statusCode, greaterThanOrEqualTo(200));
      expect(result1.statusCode, lessThan(300));
      expect(callbackCount, equals(1));

      // Wait for the token to expire
      await Future<void>.delayed(const Duration(seconds: 3));

      // Second request — token has expired, server returns 40142,
      // SDK renews via authCallback and retries
      final result2 = await client.request('GET', '/channels/$channelName');
      expect(result2.statusCode, greaterThanOrEqualTo(200));
      expect(result2.statusCode, lessThan(300));

      // The authCallback was called twice: once initially, once for renewal
      expect(callbackCount, equals(2));

      await client.close();
    });
  });

  group('RSA8 - Capability restriction', () {
    test('JWT with restricted capability is enforced by server', () async {
      final allowedChannel =
          'test-RSA8-cap-ok-${DateTime.now().millisecondsSinceEpoch}';
      final deniedChannel =
          'test-RSA8-cap-no-${DateTime.now().millisecondsSinceEpoch}';

      final jwt = JwtHelper.generateToken(
        apiKey: apiKey,
        capability: '{"$allowedChannel":["*"]}',
      );

      final client = Rest(
        options: ClientOptions(
          token: jwt,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      // Publish to allowed channel should succeed
      final publishResult = await client.request(
        'POST',
        '/channels/$allowedChannel/messages',
        body: {'name': 'test', 'data': 'hello'},
      );
      expect(publishResult.statusCode, greaterThanOrEqualTo(200));
      expect(publishResult.statusCode, lessThan(300));

      // Publish to denied channel should fail with capability error
      await expectLater(
        () => client.request(
          'POST',
          '/channels/$deniedChannel/messages',
          body: {'name': 'test', 'data': 'hello'},
        ),
        throwsA(
          isA<AblyException>().having(
            (e) => e.errorInfo?.code,
            'error code',
            equals(40160),
          ),
        ),
      );

      await client.close();
    });
  });
}
