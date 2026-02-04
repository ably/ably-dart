import 'package:ably_dart/ably_dart.dart';
import 'package:test/test.dart';

import '../../helpers/mock_http_client.dart';

/// Time API Tests
///
/// Spec points: RSC16
void main() {
  group('Time API', () {
    late MockHttpClient mockHttp;

    setUp(() {
      mockHttp = MockHttpClient();
    });

    group('RSC16 - time() returns server time', () {
      /// RSC16 - time() returns server time
      ///
      /// The time() method retrieves the server time from the /time endpoint
      /// and returns it as a DateTime or timestamp.
      test('returns server time as DateTime', () async {
        const serverTimeMs = 1704067200000; // 2024-01-01 00:00:00 UTC

        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(200, [serverTimeMs]);
          },
        );

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final result = await client.time();

        // Result should be a DateTime matching the server timestamp
        expect(result, isA<DateTime>());
        expect(result.millisecondsSinceEpoch, equals(serverTimeMs));

        // Verify correct endpoint was called
        expect(mockHttp.capturedRequests.length, equals(1));
        final request = mockHttp.capturedRequests[0];
        expect(request.method, equals('GET'));
        expect(request.url.path, equals('/time'));
      });
    });

    group('RSC16 - time() request format', () {
      /// RSC16 - time() request format
      ///
      /// The time request must be a GET request to /time with standard
      /// Ably headers.
      test('sends correctly formatted request with standard headers', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(200, [1704067200000]);
          },
        );

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.time();

        expect(mockHttp.capturedRequests.length, equals(1));
        final request = mockHttp.capturedRequests[0];

        // Should be GET request to /time
        expect(request.method, equals('GET'));
        expect(request.url.path, equals('/time'));

        // Should have standard Ably headers
        expect(request.headers.containsKey('X-Ably-Version'), isTrue);
        expect(request.headers.containsKey('Ably-Agent'), isTrue);
      });
    });

    group('RSC16 - time() does not require authentication', () {
      /// RSC16 - time() does not require authentication
      ///
      /// The /time endpoint does not require authentication and should not
      /// send an Authorization header, even when credentials are available.
      test('does not send Authorization header even with credentials',
          () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(200, [1704067200000]);
          },
        );

        // Client has credentials, but time() should not use them
        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final result = await client.time();

        // Should succeed
        expect(result, isA<DateTime>());

        // Verify the request was made without Authorization header
        expect(mockHttp.capturedRequests.length, equals(1));
        final request = mockHttp.capturedRequests[0];
        expect(request.url.path, equals('/time'));
        expect(request.headers.containsKey('Authorization'), isFalse,
            reason: 'time() should not send Authorization header');
      });
    });

    group('RSC16 - time() works without TLS', () {
      /// RSC16 - time() works without TLS
      ///
      /// The /time endpoint does not require authentication, so it should be
      /// callable over HTTP even when the client has API key credentials.
      /// The RSC18 restriction (no basic auth over non-TLS) does not apply
      /// because time() doesn't send authentication.
      test('succeeds over HTTP without sending credentials', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(200, [1704067200000]);
          },
        );

        // Client with API key but using token auth to avoid RSC18 restriction
        // on authenticated operations. time() should still work over HTTP.
        final client = Rest(
          options: ClientOptions(
            key: 'appId.keyId:keySecret',
            tls: false,
            useTokenAuth: true,
          ),
          httpClient: mockHttp,
        );

        final result = await client.time();

        // Should succeed without authentication over HTTP
        expect(result, isA<DateTime>());

        // Request should use HTTP (not HTTPS)
        expect(mockHttp.capturedRequests.length, equals(1));
        final request = mockHttp.capturedRequests[0];
        expect(request.url.scheme, equals('http'));

        // Request should not have Authorization header
        expect(request.headers.containsKey('Authorization'), isFalse,
            reason: 'time() should not send Authorization header');
      });
    });

    group('RSC16 - time() error handling', () {
      /// RSC16 - time() error handling
      ///
      /// Errors from the /time endpoint should be properly propagated to
      /// the caller.
      test('properly propagates errors from time endpoint', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(500, {
              'error': {
                'message': 'Internal server error',
                'code': 50000,
                'statusCode': 500,
              },
            });
          },
        );

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        expect(
          () => client.time(),
          throwsA(
            isA<AblyException>()
                .having((e) => e.statusCode, 'statusCode', equals(500))
                .having((e) => e.code, 'code', equals(50000)),
          ),
        );
      });
    });
  });
}
