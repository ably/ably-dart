import 'package:ably_dart/ably_dart.dart';
import 'package:test/test.dart';

import '../../helpers/mock_http_client.dart';

/// Auth Callback Tests
///
/// Spec points: RSA8c, RSA8c1a, RSA8c1b, RSA8c1c, RSA8c2, RSA8c3, RSA8d
void main() {
  group('Auth Callback', () {
    group('RSA8d - authCallback invocation', () {
      test('invokes callback with TokenParams and returns token', () async {
        final callbackInvocations = <TokenParams>[];
        final capturedRequests = <CapturedRequest>[];

        final mockHttp = MockHttpClient(
          onConnectionAttempt: (conn) => conn.respondWithSuccess(),
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(201, {
              'serials': ['s1']
            });
          },
        );

        final client = Rest(
          options: ClientOptions(
            authCallback: (tokenParams) async {
              callbackInvocations.add(tokenParams);
              return TokenDetails(
                token: 'mock-token-string',
                expires: DateTime.now().millisecondsSinceEpoch + 3600000,
                clientId: 'callback-client',
              );
            },
            clientId: 'test-client',
          ),
          httpClient: mockHttp,
        );

        // Trigger auth by making a request
        final channel = client.channels.get('test');
        await channel.publish(name: 'event', data: 'data');

        // Callback was invoked
        expect(callbackInvocations.length, greaterThanOrEqualTo(1));

        // TokenParams were passed
        expect(callbackInvocations[0], isA<TokenParams>());

        // Token was used in request
        final request = capturedRequests[0];
        expect(
          request.headers['Authorization'],
          equals('Bearer mock-token-string'),
        );
      });
    });

    group('RSA8d - authCallback returns different token types', () {
      test('accepts TokenDetails return type', () async {
        final capturedRequests = <CapturedRequest>[];

        final mockHttp = MockHttpClient(
          onConnectionAttempt: (conn) => conn.respondWithSuccess(),
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(201, {
              'serials': ['s1']
            });
          },
        );

        final client = Rest(
          options: ClientOptions(
            authCallback: (params) async => TokenDetails(
              token: 'callback-token',
              expires: DateTime.now().millisecondsSinceEpoch + 3600000,
            ),
          ),
          httpClient: mockHttp,
        );

        await client.channels.get('test').publish(name: 'e', data: 'd');

        final request = capturedRequests[0];
        expect(
          request.headers['Authorization'],
          equals('Bearer callback-token'),
        );
      });

      test('accepts String (token) return type', () async {
        final capturedRequests = <CapturedRequest>[];

        final mockHttp = MockHttpClient(
          onConnectionAttempt: (conn) => conn.respondWithSuccess(),
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(201, {
              'serials': ['s1']
            });
          },
        );

        final client = Rest(
          options: ClientOptions(
            authCallback: (params) async => 'raw-string-token',
          ),
          httpClient: mockHttp,
        );

        await client.channels.get('test').publish(name: 'e', data: 'd');

        final request = capturedRequests[0];
        expect(
          request.headers['Authorization'],
          equals('Bearer raw-string-token'),
        );
      });

      test('accepts TokenRequest return type', () async {
        final capturedRequests = <CapturedRequest>[];

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
              // First request: exchange TokenRequest for TokenDetails
              req.respondWith(200, {
                'token': 'exchanged-token',
                'expires': DateTime.now().millisecondsSinceEpoch + 3600000,
                'keyName': 'appId.keyId',
              });
            } else {
              // Second request: actual publish
              req.respondWith(201, {
                'serials': ['s1']
              });
            }
          },
        );

        final client = Rest(
          options: ClientOptions(
            authCallback: (params) async => TokenRequest(
              keyName: 'appId.keyId',
              ttl: 3600000,
              timestamp: DateTime.now().millisecondsSinceEpoch,
              nonce: 'unique-nonce',
              mac: 'valid-mac-signature',
            ),
          ),
          httpClient: mockHttp,
        );

        await client.channels.get('test').publish(name: 'e', data: 'd');

        // First request should be token exchange
        expect(
          capturedRequests[0].url.path,
          equals('/keys/appId.keyId/requestToken'),
        );

        // Second request should use exchanged token
        expect(
          capturedRequests[1].headers['Authorization'],
          equals('Bearer exchanged-token'),
        );
      });
    });

    group('RSA8c - authUrl queries URL for token', () {
      test('queries authUrl to obtain a token', () async {
        final capturedRequests = <CapturedRequest>[];

        final mockHttp = MockHttpClient(
          onConnectionAttempt: (conn) => conn.respondWithSuccess(),
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            if (req.url.host == 'auth.example.com') {
              // Response from authUrl
              req.respondWith(
                200,
                {'token': 'authurl-token', 'expires': 9999999999999},
                headers: {'Content-Type': 'application/json'},
              );
            } else {
              // Response from Ably for publish
              req.respondWith(201, {
                'serials': ['s1']
              });
            }
          },
        );

        final client = Rest(
          options: ClientOptions(
            authUrl: 'https://auth.example.com/get-token',
          ),
          httpClient: mockHttp,
        );

        await client.channels.get('test').publish(name: 'e', data: 'd');

        // First request goes to authUrl
        final authRequest = capturedRequests[0];
        expect(authRequest.url.host, equals('auth.example.com'));
        expect(authRequest.url.path, equals('/get-token'));

        // Subsequent request uses obtained token
        final publishRequest = capturedRequests[1];
        expect(
          publishRequest.headers['Authorization'],
          equals('Bearer authurl-token'),
        );
      });
    });

    group('RSA8c1a - authUrl with GET method', () {
      test('sends TokenParams and authParams as query string', () async {
        final capturedRequests = <CapturedRequest>[];

        final mockHttp = MockHttpClient(
          onConnectionAttempt: (conn) => conn.respondWithSuccess(),
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            if (req.url.host == 'auth.example.com') {
              req.respondWith(
                200,
                'plain-token-string',
                headers: {'Content-Type': 'text/plain'},
              );
            } else {
              req.respondWith(201, {
                'serials': ['s1']
              });
            }
          },
        );

        final client = Rest(
          options: ClientOptions(
            authUrl: 'https://auth.example.com/token',
            authMethod: 'GET',
            authParams: {'custom': 'param1'},
            authHeaders: {'X-Custom-Header': 'value1'},
          ),
          httpClient: mockHttp,
        );

        await client.channels.get('test').publish(name: 'e', data: 'd');

        final authRequest = capturedRequests[0];

        expect(authRequest.method, equals('GET'));
        expect(authRequest.url.queryParameters['custom'], equals('param1'));
        expect(authRequest.headers['X-Custom-Header'], equals('value1'));
        expect(authRequest.body, isEmpty);
      });
    });

    group('RSA8c1b - authUrl with POST method', () {
      test('sends TokenParams and authParams as form-encoded body', () async {
        final capturedRequests = <CapturedRequest>[];

        final mockHttp = MockHttpClient(
          onConnectionAttempt: (conn) => conn.respondWithSuccess(),
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            if (req.url.host == 'auth.example.com') {
              req.respondWith(
                200,
                {'token': 'post-token'},
                headers: {'Content-Type': 'application/json'},
              );
            } else {
              req.respondWith(201, {
                'serials': ['s1']
              });
            }
          },
        );

        final client = Rest(
          options: ClientOptions(
            authUrl: 'https://auth.example.com/token',
            authMethod: 'POST',
            authParams: {'custom': 'param1'},
            authHeaders: {'X-Custom-Header': 'value1'},
          ),
          httpClient: mockHttp,
        );

        await client.channels.get('test').publish(name: 'e', data: 'd');

        final authRequest = capturedRequests[0];

        expect(authRequest.method, equals('POST'));
        expect(
          authRequest.headers['Content-Type'],
          equals('application/x-www-form-urlencoded'),
        );
        expect(authRequest.headers['X-Custom-Header'], equals('value1'));

        // Body should contain form params
        expect(authRequest.body, contains('custom=param1'));
      });
    });

    group('RSA8c1c - authUrl preserves existing query params', () {
      test('merges existing and new query params', () async {
        final capturedRequests = <CapturedRequest>[];

        final mockHttp = MockHttpClient(
          onConnectionAttempt: (conn) => conn.respondWithSuccess(),
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            if (req.url.host == 'auth.example.com') {
              req.respondWith(
                200,
                {'token': 'merged-token'},
                headers: {'Content-Type': 'application/json'},
              );
            } else {
              req.respondWith(201, {
                'serials': ['s1']
              });
            }
          },
        );

        final client = Rest(
          options: ClientOptions(
            authUrl:
                'https://auth.example.com/token?existing=value&another=123',
            authMethod: 'GET',
            authParams: {'added': 'new'},
          ),
          httpClient: mockHttp,
        );

        await client.channels.get('test').publish(name: 'e', data: 'd');

        final authRequest = capturedRequests[0];

        // All params should be present
        expect(authRequest.url.queryParameters['existing'], equals('value'));
        expect(authRequest.url.queryParameters['another'], equals('123'));
        expect(authRequest.url.queryParameters['added'], equals('new'));
      });
    });

    group('RSA8c2 - TokenParams take precedence over authParams', () {
      test('uses TokenParams values when names conflict', () async {
        final capturedRequests = <CapturedRequest>[];

        final mockHttp = MockHttpClient(
          onConnectionAttempt: (conn) => conn.respondWithSuccess(),
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            if (req.url.host == 'auth.example.com') {
              req.respondWith(
                200,
                {'token': 'precedence-token'},
                headers: {'Content-Type': 'application/json'},
              );
            } else {
              req.respondWith(201, {
                'serials': ['s1']
              });
            }
          },
        );

        final client = Rest(
          options: ClientOptions(
            authUrl: 'https://auth.example.com/token',
            authMethod: 'GET',
            authParams: {
              'clientId': 'from-authParams',
              'custom': 'authParams-value',
            },
            clientId: 'from-tokenParams', // This becomes part of TokenParams
          ),
          httpClient: mockHttp,
        );

        await client.channels.get('test').publish(name: 'e', data: 'd');

        final authRequest = capturedRequests[0];

        // TokenParams.clientId should override authParams.clientId
        expect(
          authRequest.url.queryParameters['clientId'],
          equals('from-tokenParams'),
        );
        // Non-conflicting authParams preserved
        expect(
          authRequest.url.queryParameters['custom'],
          equals('authParams-value'),
        );
      });
    });
  });
}
