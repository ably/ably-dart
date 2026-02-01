import 'package:ably_dart/ably_dart.dart';
import 'package:test/test.dart';

import '../../helpers/mock_http_client.dart';

/// Token Renewal Tests
///
/// Spec points: RSA4b4, RSA14
void main() {
  group('Token Renewal', () {
    late MockHttpClient mockHttp;

    setUp(() {
      mockHttp = MockHttpClient();
    });

    group('RSA4b4 - Token renewal on expiry rejection', () {
      /// Tests that when a request is rejected with error code 40142
      /// (token expired), the library obtains a new token via the auth
      /// callback and retries the request automatically.
      test('obtains new token and retries on 40142 error', () async {
        var callbackCount = 0;
        final tokens = ['first-token', 'second-token'];
        final capturedRequests = <CapturedRequest>[];
        var requestCount = 0;

        final authCallback = (TokenParams params) async {
          final token = tokens[callbackCount];
          callbackCount++;
          return TokenDetails(
            token: token,
            expires: DateTime.now().millisecondsSinceEpoch + 3600000,
          );
        };

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));
            requestCount++;

            if (requestCount == 1) {
              // First request fails with token expired
              req.respondWith(401, {
                'error': {
                  'code': 40142,
                  'statusCode': 401,
                  'message': 'Token expired',
                },
              });
            } else {
              // Second request (after renewal) succeeds
              req.respondWith(200, [
                {'channel': 'test'}
              ]);
            }
          },
        );

        final client = Rest(
          options: ClientOptions(authCallback: authCallback),
          httpClient: mockHttp,
        );

        final result = await client.channels.get('test').history();

        // authCallback was called twice (initial + renewal)
        expect(callbackCount, equals(2));

        // Two HTTP requests were made
        expect(requestCount, equals(2));

        // First request used first token
        expect(
          capturedRequests[0].headers['Authorization'],
          equals('Bearer first-token'),
        );

        // Second request used renewed token
        expect(
          capturedRequests[1].headers['Authorization'],
          equals('Bearer second-token'),
        );

        // Final result is successful
        expect(result.items, isA<List>());
      });
    });

    group('RSA4b4 - Token renewal on 40140 error', () {
      /// Tests renewal is triggered for error code 40140 (token error).
      test('obtains new token and retries on 40140 error', () async {
        var callbackCount = 0;
        var requestCount = 0;

        final authCallback = (TokenParams params) async {
          callbackCount++;
          return TokenDetails(
            token: 'token-$callbackCount',
            expires: DateTime.now().millisecondsSinceEpoch + 3600000,
          );
        };

        mockHttp = MockHttpClient(
          onRequest: (req) {
            requestCount++;
            if (requestCount == 1) {
              // First attempt fails with 40140
              req.respondWith(401, {
                'error': {
                  'code': 40140,
                  'statusCode': 401,
                  'message': 'Token error',
                },
              });
            } else {
              // Retry succeeds
              req.respondWith(200, []);
            }
          },
        );

        final client = Rest(
          options: ClientOptions(authCallback: authCallback),
          httpClient: mockHttp,
        );

        await client.channels.get('test').history();

        expect(callbackCount, equals(2));
        expect(requestCount, equals(2));
      });
    });

    group('RSA14 - Pre-emptive token renewal', () {
      /// Tests that if a token is known to be expired before making a request,
      /// renewal happens without first making a failing request.
      test('renews expired token pre-emptively', () async {
        var callbackCount = 0;
        final capturedRequests = <CapturedRequest>[];

        final authCallback = (TokenParams params) async {
          callbackCount++;
          if (callbackCount == 1) {
            // First token is already expired
            return TokenDetails(
              token: 'expired-token',
              expires: DateTime.now().millisecondsSinceEpoch - 1000,
            );
          } else {
            return TokenDetails(
              token: 'fresh-token',
              expires: DateTime.now().millisecondsSinceEpoch + 3600000,
            );
          }
        };

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));
            // Only success response (no 401 expected)
            req.respondWith(200, []);
          },
        );

        final client = Rest(
          options: ClientOptions(authCallback: authCallback),
          httpClient: mockHttp,
        );

        // Force initial token acquisition
        await client.auth.authorize();

        // This should detect expired token and renew before request
        await client.channels.get('test').history();

        // Callback was called twice (initial + pre-emptive renewal)
        expect(callbackCount, equals(2));

        // Only ONE HTTP request to the API (history)
        // No failed request with expired token
        final requestsToChannels = capturedRequests
            .where((r) => r.url.path.contains('/channels/'))
            .toList();
        expect(requestsToChannels.length, equals(1));
        expect(
          requestsToChannels[0].headers['Authorization'],
          equals('Bearer fresh-token'),
        );
      });
    });

    group('RSA4b4 - No renewal without authCallback', () {
      /// Tests that token renewal is not attempted if no renewal mechanism
      /// (authCallback/authUrl/key) is available.
      test('does not retry without renewal mechanism', () async {
        var requestCount = 0;

        mockHttp = MockHttpClient(
          onRequest: (req) {
            requestCount++;
            req.respondWith(401, {
              'error': {
                'code': 40142,
                'statusCode': 401,
                'message': 'Token expired',
              },
            });
          },
        );

        // Client with explicit token but no authCallback
        final client = Rest(
          options: ClientOptions(token: 'static-token'),
          httpClient: mockHttp,
        );

        try {
          await client.channels.get('test').history();
          fail('Expected token expired error');
        } catch (e) {
          expect(e, isA<AblyException>());
          final ablyException = e as AblyException;
          expect(ablyException.code, equals(40142));
        }

        // Only one request was made (no retry)
        expect(requestCount, equals(1));
      });
    });

    group('RSA4b4 - Renewal with authUrl', () {
      /// Tests that token renewal works via authUrl.
      test('renews token via authUrl on 40142 error', () async {
        final capturedRequests = <CapturedRequest>[];
        var requestCount = 0;

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));
            requestCount++;

            if (req.url.host == 'example.com') {
              // authUrl requests - return tokens
              if (requestCount == 1) {
                req.respondWith(200, {
                  'token': 'first-token',
                  'expires': DateTime.now().millisecondsSinceEpoch + 3600000,
                });
              } else {
                // Second token request (renewal)
                req.respondWith(200, {
                  'token': 'second-token',
                  'expires': DateTime.now().millisecondsSinceEpoch + 3600000,
                });
              }
            } else {
              // API requests
              if (requestCount == 2) {
                // First API request fails
                req.respondWith(401, {
                  'error': {'code': 40142, 'message': 'Token expired'},
                });
              } else {
                // Retry succeeds
                req.respondWith(200, []);
              }
            }
          },
        );

        final client = Rest(
          options: ClientOptions(
            authUrl: 'https://example.com/auth',
          ),
          httpClient: mockHttp,
        );

        await client.channels.get('test').history();

        // Two requests to authUrl
        final authRequests = capturedRequests
            .where((r) => r.url.host == 'example.com')
            .toList();
        expect(authRequests.length, equals(2));

        // Two requests to Ably API
        final apiRequests = capturedRequests
            .where((r) => r.url.host != 'example.com')
            .toList();
        expect(apiRequests.length, equals(2));

        // Second API request used renewed token
        expect(
          apiRequests[1].headers['Authorization'],
          equals('Bearer second-token'),
        );
      });
    });

    group('RSA4b4 - Renewal limit', () {
      /// Tests that token renewal doesn't loop infinitely if server keeps
      /// rejecting tokens.
      test('stops retrying after max attempts', () async {
        var callbackCount = 0;
        var requestCount = 0;

        final authCallback = (TokenParams params) async {
          callbackCount++;
          return TokenDetails(
            token: 'token-$callbackCount',
            expires: DateTime.now().millisecondsSinceEpoch + 3600000,
          );
        };

        mockHttp = MockHttpClient(
          onRequest: (req) {
            requestCount++;
            // Always return token expired
            req.respondWith(401, {
              'error': {'code': 40142, 'message': 'Token expired'},
            });
          },
        );

        final client = Rest(
          options: ClientOptions(authCallback: authCallback),
          httpClient: mockHttp,
        );

        try {
          await client.channels.get('test').history();
          fail('Expected error after max retries');
        } catch (e) {
          // Should eventually give up
          expect(e, isA<AblyException>());
          final ablyException = e as AblyException;
          expect(ablyException.code, equals(40142));
        }

        // Should not retry indefinitely (implementation-specific limit)
        expect(callbackCount, lessThanOrEqualTo(3)); // Reasonable retry limit
        expect(requestCount, lessThanOrEqualTo(3)); // Should stop making requests
      });
    });
  });
}
