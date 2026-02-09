import 'dart:convert';

import 'package:ably_dart/ably_dart.dart';
import 'package:test/test.dart';

import '../../helpers/mock_http_client.dart';
import '../../helpers/test_channel_name.dart';

/// Auth Scheme Selection Tests
///
/// Spec points: RSA1, RSA2, RSA3, RSA4, RSA4a, RSA4b, RSA4c, RSA11
void main() {
  group('Auth Scheme Selection', () {
    group('RSA1 - API key format validation', () {
      final testCases = [
        (input: 'appId.keyId:keySecret', expected: 'Valid'),
        (input: 'appId.keyId', expected: 'Invalid'),
        (input: 'invalid-format', expected: 'Invalid'),
        (input: '', expected: 'Invalid'),
        (input: 'a.b:c', expected: 'Valid'),
      ];

      for (final testCase in testCases) {
        test('${testCase.input} is ${testCase.expected}', () {
          if (testCase.expected == 'Valid') {
            expect(
              () => ClientOptions.fromKey(testCase.input),
              returnsNormally,
            );
          } else {
            expect(
              () => ClientOptions.fromKey(testCase.input),
              throwsA(isA<ArgumentError>()),
            );
          }
        });
      }
    });

    group('RSA2, RSA11 - Basic auth when using API key', () {
      test('uses Basic authentication header', () async {
        final capturedRequests = <CapturedRequest>[];
        final channelName = testChannelName('RSA2');

        final mockHttp = MockHttpClient(
          onConnectionAttempt: (conn) => conn.respondWithSuccess(),
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(200, {
              'channelId': channelName,
              'status': {'isActive': true}
            });
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.channels.get(channelName).status();

        final request = capturedRequests[0];
        final authHeader = request.headers['Authorization'];

        expect(authHeader, startsWith('Basic '));

        // Decode and verify
        final credentials = utf8.decode(
          base64.decode(authHeader!.substring(6)),
        );
        expect(credentials, equals('appId.keyId:keySecret'));
      });
    });

    group('RSA3 - Token auth when token provided', () {
      test('uses Bearer token authentication header', () async {
        final capturedRequests = <CapturedRequest>[];
        final channelName = testChannelName('RSA3');

        final mockHttp = MockHttpClient(
          onConnectionAttempt: (conn) => conn.respondWithSuccess(),
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(200, {
              'channelId': channelName,
              'status': {'isActive': true}
            });
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions(token: 'my-token-string'),
          httpClient: mockHttp,
        );

        await client.channels.get(channelName).status();

        final request = capturedRequests[0];
        expect(
          request.headers['Authorization'],
          equals('Bearer my-token-string'),
        );
      });

      test('extracts token from TokenDetails', () async {
        final capturedRequests = <CapturedRequest>[];
        final channelName = testChannelName('RSA3-details');

        final mockHttp = MockHttpClient(
          onConnectionAttempt: (conn) => conn.respondWithSuccess(),
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(200, {
              'channelId': channelName,
              'status': {'isActive': true}
            });
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions(
            tokenDetails: TokenDetails(
              token: 'token-from-details',
              expires: DateTime.now().millisecondsSinceEpoch + 3600000,
            ),
          ),
          httpClient: mockHttp,
        );

        await client.channels.get(channelName).status();

        final request = capturedRequests[0];
        expect(
          request.headers['Authorization'],
          equals('Bearer token-from-details'),
        );
      });
    });

    group('RSA4 - Auth method selection priority', () {
      test('RSA4a - authCallback takes precedence', () async {
        final capturedRequests = <CapturedRequest>[];
        final channelName = testChannelName('RSA4a');

        final mockHttp = MockHttpClient(
          onConnectionAttempt: (conn) => conn.respondWithSuccess(),
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(200, {
              'channelId': channelName,
              'status': {'isActive': true}
            });
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions(
            authCallback: (params) async => TokenDetails(
              token: 'callback-token',
              expires: DateTime.now().millisecondsSinceEpoch + 3600000,
            ),
          ),
          httpClient: mockHttp,
        );

        await client.channels.get(channelName).status();

        final request = capturedRequests[0];
        expect(
          request.headers['Authorization'],
          equals('Bearer callback-token'),
        );
      });

      test('RSA4b - key + clientId triggers token auth', () async {
        final capturedRequests = <CapturedRequest>[];
        final channelName = testChannelName('RSA4b');

        final mockHttp = MockHttpClient(
          onConnectionAttempt: (conn) => conn.respondWithSuccess(),
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            if (req.url.path.contains('requestToken')) {
              // Token request
              req.respondWith(200, {
                'token': 'auto-token',
                'expires': DateTime.now().millisecondsSinceEpoch + 3600000,
                'keyName': 'appId.keyId',
              });
            } else {
              // Actual request
              req.respondWith(200, {
                'channelId': channelName,
                'status': {'isActive': true}
              });
            }
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions(
            key: 'appId.keyId:keySecret',
            clientId: 'my-client',
          ),
          httpClient: mockHttp,
        );

        await client.channels.get(channelName).status();

        // First request should be token creation
        expect(
          capturedRequests[0].url.path,
          contains('requestToken'),
        );

        // Second request should use Bearer token
        expect(
          capturedRequests[1].headers['Authorization'],
          startsWith('Bearer '),
        );
      });

      test('RSA4c - key only uses Basic auth', () async {
        final capturedRequests = <CapturedRequest>[];
        final channelName = testChannelName('RSA4c');

        final mockHttp = MockHttpClient(
          onConnectionAttempt: (conn) => conn.respondWithSuccess(),
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(200, {
              'channelId': channelName,
              'status': {'isActive': true}
            });
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.channels.get(channelName).status();

        final request = capturedRequests[0];
        expect(request.headers['Authorization'], startsWith('Basic '));
      });

      test('authCallback takes precedence over key', () async {
        final capturedRequests = <CapturedRequest>[];
        final channelName = testChannelName('RSA4-callback');

        final mockHttp = MockHttpClient(
          onConnectionAttempt: (conn) => conn.respondWithSuccess(),
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(200, {
              'channelId': channelName,
              'status': {'isActive': true}
            });
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions(
            key: 'appId.keyId:keySecret',
            authCallback: (params) async => 'callback-wins',
          ),
          httpClient: mockHttp,
        );

        await client.channels.get(channelName).status();

        final request = capturedRequests[0];
        expect(
          request.headers['Authorization'],
          equals('Bearer callback-wins'),
        );
      });

      test('explicit token takes precedence over key', () async {
        final capturedRequests = <CapturedRequest>[];
        final channelName = testChannelName('RSA4-token');

        final mockHttp = MockHttpClient(
          onConnectionAttempt: (conn) => conn.respondWithSuccess(),
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(200, {
              'channelId': channelName,
              'status': {'isActive': true}
            });
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions(
            key: 'appId.keyId:keySecret',
            token: 'explicit-token',
          ),
          httpClient: mockHttp,
        );

        await client.channels.get(channelName).status();

        final request = capturedRequests[0];
        expect(
          request.headers['Authorization'],
          equals('Bearer explicit-token'),
        );
      });
    });

    group('RSA4 - No auth credentials error', () {
      test('throws error when no authentication method is configured', () {
        expect(
          () => Rest(options: ClientOptions()),
          throwsA(
            isA<AblyException>().having(
              (e) => e.code,
              'code',
              equals(40106),
            ),
          ),
        );
      });
    });
  });
}
