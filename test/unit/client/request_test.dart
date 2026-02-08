import 'dart:convert';

import 'package:ably_dart/ably_dart.dart';
import 'package:test/test.dart';

import '../../helpers/mock_http_client.dart';

/// REST Client request() Tests
///
/// Spec points: RSC19, HP1-HP8
void main() {
  group('REST Client request()', () {
    late MockHttpClient mockHttp;

    setUp(() {
      mockHttp = MockHttpClient();
    });

    group('RSC19f - Method and parameters', () {
      test('supports GET method', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(200, []);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.request('GET', '/test');

        final request = capturedRequests[0];
        expect(request.method, equals('GET'));
      });

      test('supports POST method', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(201, []);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.request('POST', '/test', body: {'data': 'value'});

        final request = capturedRequests[0];
        expect(request.method, equals('POST'));
      });

      test('supports PUT method', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(200, []);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.request('PUT', '/test', body: {'data': 'value'});

        final request = capturedRequests[0];
        expect(request.method, equals('PUT'));
      });

      test('supports PATCH method', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(200, []);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.request('PATCH', '/test', body: {'data': 'value'});

        final request = capturedRequests[0];
        expect(request.method, equals('PATCH'));
      });

      test('supports DELETE method', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(204, '');
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.request('DELETE', '/test');

        final request = capturedRequests[0];
        expect(request.method, equals('DELETE'));
      });

      test('query parameters passed correctly', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(200, []);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.request(
          'GET',
          '/test',
          params: {'foo': 'bar', 'baz': '123'},
        );

        final request = capturedRequests[0];
        expect(request.url.queryParameters['foo'], equals('bar'));
        expect(request.url.queryParameters['baz'], equals('123'));
      });

      test('custom headers passed correctly', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(200, []);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.request(
          'GET',
          '/test',
          headers: {'X-Custom-Header': 'custom-value'},
        );

        final request = capturedRequests[0];
        expect(request.headers['X-Custom-Header'], equals('custom-value'));
      });

      test('request body sent correctly', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(201, []);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.request(
          'POST',
          '/test',
          body: {'name': 'test', 'value': 42},
        );

        final request = capturedRequests[0];
        final body = json.decode(request.body!) as Map;
        expect(body['name'], equals('test'));
        expect(body['value'], equals(42));
      });
    });

    group('RSC19f1 - Version parameter', () {
      test('uses explicit version parameter when provided', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(200, []);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.request('GET', '/test', version: 3);

        final request = capturedRequests[0];
        expect(request.headers['X-Ably-Version'], equals('3'));
      });

      test('uses default version when not provided', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(200, []);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.request('GET', '/test');

        final request = capturedRequests[0];
        expect(request.headers['X-Ably-Version'], equals('2'));
      });
    });

    group('RSC19b - Authentication', () {
      test('uses configured Basic authentication', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(200, []);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.request('GET', '/test');

        final request = capturedRequests[0];
        expect(request.headers['Authorization'], startsWith('Basic '));
      });

      test('uses configured Token authentication', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(200, []);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions(token: 'test-token'),
          httpClient: mockHttp,
        );

        await client.request('GET', '/test');

        final request = capturedRequests[0];
        expect(request.headers['Authorization'], equals('Bearer test-token'));
      });

      test('cannot override authentication header', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(200, []);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.request(
          'GET',
          '/test',
          headers: {'Authorization': 'Bearer malicious-token'},
        );

        final request = capturedRequests[0];
        // Should still use Basic auth, not the custom header
        expect(request.headers['Authorization'], startsWith('Basic '));
      });
    });

    group('RSC19c - Protocol handling', () {
      test('JSON protocol sets correct headers', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(200, []);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions(
            key: 'appId.keyId:keySecret',
            useBinaryProtocol: false,
          ),
          httpClient: mockHttp,
        );

        await client.request('GET', '/test');

        final request = capturedRequests[0];
        expect(request.headers['Accept'], equals('application/json'));
      });

      test('MsgPack protocol sets correct headers', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(200, []);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions(
            key: 'appId.keyId:keySecret',
            useBinaryProtocol: true,
          ),
          httpClient: mockHttp,
        );

        await client.request('GET', '/test');

        final request = capturedRequests[0];
        expect(request.headers['Accept'], equals('application/x-msgpack'));
      });

      test('request body encoded according to protocol', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(201, []);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions(
            key: 'appId.keyId:keySecret',
            useBinaryProtocol: false,
          ),
          httpClient: mockHttp,
        );

        await client.request('POST', '/test', body: {'data': 'value'});

        final request = capturedRequests[0];
        expect(request.headers['Content-Type'], equals('application/json'));
        expect(request.body, equals('{"data":"value"}'));
      });
    });

    group('RSC19d, HP - HttpPaginatedResponse', () {
      test('HP4 - provides status code', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(201, []);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final response = await client.request('POST', '/test');

        expect(response.statusCode, equals(201));
      });

      test('HP5 - provides success indicator', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(200, []);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final response = await client.request('GET', '/test');

        expect(response.success, isTrue);
      });

      test('HP6 - error code from header when error response', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            // 4xx errors throw AblyException
            req.respondWith(
              400,
              {
                'error': {'message': 'Bad request', 'code': 40000}
              },
              headers: {'X-Ably-Errorcode': '40000'},
            );
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        try {
          await client.request('GET', '/test');
          fail('Expected AblyException');
        } on AblyException catch (e) {
          expect(e.code, equals(40000));
        }
      });

      test('HP7 - error message from header when error response', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(
              400,
              {
                'error': {'message': 'Invalid request', 'code': 40000}
              },
              headers: {'X-Ably-Errormessage': 'Invalid request'},
            );
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await expectLater(
          client.request('GET', '/test'),
          throwsA(
            isA<AblyException>().having(
              (e) => e.message,
              'message',
              contains('Invalid request'),
            ),
          ),
        );
      });

      test('HP8 - provides all response headers', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(
              200,
              [],
              headers: {
                'X-Custom-Header': 'custom-value',
                'Content-Type': 'application/json',
              },
            );
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final response = await client.request('GET', '/test');

        expect(response.headers['x-custom-header'], equals('custom-value'));
        expect(response.headers['content-type'], equals('application/json'));
      });

      test('HP3 - provides response items', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(200, [
              {'id': '1', 'name': 'item1'},
              {'id': '2', 'name': 'item2'},
            ]);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final response = await client.request('GET', '/test');

        expect(response.items.length, equals(2));
        expect(response.items[0]['id'], equals('1'));
        expect(response.items[1]['name'], equals('item2'));
      });

      test('HP1 - pagination support with Link header', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(
              200,
              [
                {'id': '1'}
              ],
              headers: {'Link': '</test?page=2>; rel="next"'},
            );
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final response = await client.request('GET', '/test');

        expect(response.hasNext(), isTrue);
        expect(response.isLast(), isFalse);
      });

      test('non-array response handling', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(200, {'single': 'object'});
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final response = await client.request('GET', '/test');

        // Non-array responses are wrapped in a list
        expect(response.items.length, equals(1));
        expect(response.items[0]['single'], equals('object'));
      });

      test('empty response handling (204 No Content)', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(204, '');
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final response = await client.request('DELETE', '/test');

        expect(response.statusCode, equals(204));
        expect(response.items, isEmpty);
      });
    });

    group('RSC19e - Error handling', () {
      test('network error handling', () async {
        mockHttp = MockHttpClient(
          onConnectionAttempt: (conn) {
            conn.respondWithRefused();
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        expect(
          () => client.request('GET', '/test'),
          throwsA(isA<AblyException>()),
        );
      });

      test('timeout error handling', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWithTimeout();
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        expect(
          () => client.request('GET', '/test'),
          throwsA(isA<AblyException>()),
        );
      });
    });

    group('RSC19f - Path handling', () {
      test('path with leading slash', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(200, []);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.request('GET', '/channels/test/messages');

        final request = capturedRequests[0];
        expect(request.url.path, equals('/channels/test/messages'));
      });

      test('path without leading slash', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(200, []);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.request('GET', 'channels/test/messages');

        final request = capturedRequests[0];
        expect(request.url.path, equals('/channels/test/messages'));
      });
    });

    group('Request headers', () {
      test('includes standard Ably headers', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(200, []);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.request('GET', '/test');

        final request = capturedRequests[0];
        expect(request.headers['X-Ably-Version'], isNotNull);
        expect(request.headers['Ably-Agent'], isNotNull);
        expect(request.headers['Authorization'], isNotNull);
      });
    });
  });
}
