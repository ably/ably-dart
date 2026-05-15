import 'package:test/test.dart';
import 'mock_http_client.dart';

void main() {
  group('MockHttpClient - Handler-based interface', () {
    late MockHttpClient mock;

    tearDown(() {
      mock.dispose();
    });

    test('handler-based request handling', () async {
      mock = MockHttpClient(
        onRequest: (request) {
          if (request.url.path == '/time') {
            request.respondWith(200, {'time': 1234567890000});
          } else {
            request.respondWith(404, {
              'error': {'code': 40400},
            });
          }
        },
      );

      // Make a request
      final response =
          await mock.get(Uri.parse('https://main.realtime.ably.net/time'));

      expect(response.statusCode, 200);
      expect(mock.capturedRequests.length, 1);
      expect(mock.capturedRequests[0].url.path, '/time');
    });

    test('connection attempt handling', () async {
      mock = MockHttpClient(
        onConnectionAttempt: (connection) {
          expect(connection.host, 'main.realtime.ably.net');
          expect(connection.tls, true);
          connection.respondWithSuccess();
        },
        onRequest: (request) {
          request.respondWith(200, {'success': true});
        },
      );

      final response =
          await mock.get(Uri.parse('https://main.realtime.ably.net/test'));
      expect(response.statusCode, 200);
    });

    test('connection refused simulation', () async {
      mock = MockHttpClient(
        onConnectionAttempt: (connection) {
          connection.respondWithRefused();
        },
      );

      expect(
        () => mock.get(Uri.parse('https://main.realtime.ably.net/test')),
        throwsA(isA<Exception>()),
      );
    });

    test('connection timeout simulation', () async {
      mock = MockHttpClient(
        onConnectionAttempt: (connection) {
          connection.respondWithTimeout();
        },
      );

      expect(
        () => mock.get(Uri.parse('https://main.realtime.ably.net/test')),
        throwsA(isA<Exception>()),
      );
    });

    test('DNS error simulation', () async {
      mock = MockHttpClient(
        onConnectionAttempt: (connection) {
          connection.respondWithDnsError();
        },
      );

      expect(
        () => mock.get(Uri.parse('https://main.realtime.ably.net/test')),
        throwsA(isA<Exception>()),
      );
    });

    test('request timeout simulation', () async {
      mock = MockHttpClient(
        onRequest: (request) {
          request.respondWithTimeout();
        },
      );

      expect(
        () => mock.get(Uri.parse('https://main.realtime.ably.net/test')),
        throwsA(isA<Exception>()),
      );
    });

    test('multiple requests with different responses', () async {
      var requestCount = 0;
      mock = MockHttpClient(
        onRequest: (request) {
          requestCount++;
          if (requestCount == 1) {
            request.respondWith(200, {'first': true});
          } else {
            request.respondWith(201, {'second': true});
          }
        },
      );

      final response1 =
          await mock.get(Uri.parse('https://main.realtime.ably.net/test'));
      expect(response1.statusCode, 200);

      final response2 =
          await mock.get(Uri.parse('https://main.realtime.ably.net/test'));
      expect(response2.statusCode, 201);

      expect(mock.capturedRequests.length, 2);
    });

    test('request headers are captured', () async {
      mock = MockHttpClient(
        onRequest: (request) {
          expect(request.headers['X-Custom-Header'], 'test-value');
          request.respondWith(200, {});
        },
      );

      await mock.get(
        Uri.parse('https://main.realtime.ably.net/test'),
        headers: {'X-Custom-Header': 'test-value'},
      );
    });

    test('response headers are returned', () async {
      mock = MockHttpClient(
        onRequest: (request) {
          request.respondWith(
            200,
            {'data': 'test'},
            headers: {'x-response-header': 'response-value'},
          );
        },
      );

      final response =
          await mock.get(Uri.parse('https://main.realtime.ably.net/test'));
      expect(response.headers['x-response-header'], 'response-value');
      // Note: content-type is set by StreamedResponse, not always in headers map
    });
  });

  group('MockHttpClient - Awaitable interface', () {
    late MockHttpClient mock;

    tearDown(() {
      mock.dispose();
    });

    test('awaitable request', () async {
      mock = MockHttpClient();

      // Start a request in the background
      final requestFuture =
          mock.get(Uri.parse('https://main.realtime.ably.net/test'));

      // Await the request in test code
      final pendingRequest = await mock.awaitRequest();

      expect(pendingRequest.url.path, '/test');
      expect(pendingRequest.method, 'GET');

      // Respond to it
      pendingRequest.respondWith(200, {'data': 'test'});

      final response = await requestFuture;
      expect(response.statusCode, 200);
    });

    test('awaitable connection attempt', () async {
      mock = MockHttpClient();

      // Start a request in the background
      final requestFuture =
          mock.get(Uri.parse('https://main.realtime.ably.net/test'));

      // Both connection and request will be emitted
      final request = await mock.awaitRequest();
      expect(request.url.host, 'main.realtime.ably.net');
      request.respondWith(200, {});

      await requestFuture;
    });

    test('awaitable connection refusal', () async {
      mock = MockHttpClient(
        onConnectionAttempt: (conn) {
          conn.respondWithRefused();
        },
      );

      expect(
        () => mock.get(Uri.parse('https://main.realtime.ably.net/test')),
        throwsA(isA<Exception>()),
      );
    });

    test('PendingRequest body parsing', () async {
      mock = MockHttpClient();

      final requestFuture = mock.post(
        Uri.parse('https://main.realtime.ably.net/channels/test/messages'),
        body: '{"name":"event","data":"payload"}',
      );

      final request = await mock.awaitRequest();
      expect(request.bodyAsString, '{"name":"event","data":"payload"}');

      final json = request.jsonBody;
      expect(json['name'], 'event');
      expect(json['data'], 'payload');

      request.respondWith(200, {'success': true});
      await requestFuture;
    });

    test('delayed response', () async {
      mock = MockHttpClient(
        onRequest: (request) {
          request.respondWithDelay(
            const Duration(milliseconds: 50),
            200,
            {'delayed': true},
          );
        },
      );

      final stopwatch = Stopwatch()..start();
      final response =
          await mock.get(Uri.parse('https://main.realtime.ably.net/test'));
      stopwatch.stop();

      expect(response.statusCode, 200);
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(45));
    });
  });

  group('MockHttpClient - Request capture', () {
    late MockHttpClient mock;

    tearDown(() {
      mock.dispose();
    });

    test('capturedRequests stores all requests', () async {
      mock = MockHttpClient(
        onRequest: (request) => request.respondWith(200, {}),
      );

      await mock.get(Uri.parse('https://main.realtime.ably.net/test1'));
      await mock.post(Uri.parse('https://main.realtime.ably.net/test2'));
      await mock.put(Uri.parse('https://main.realtime.ably.net/test3'));

      expect(mock.capturedRequests.length, 3);
      expect(mock.capturedRequests[0].method, 'GET');
      expect(mock.capturedRequests[0].url.path, '/test1');
      expect(mock.capturedRequests[1].method, 'POST');
      expect(mock.capturedRequests[1].url.path, '/test2');
      expect(mock.capturedRequests[2].method, 'PUT');
      expect(mock.capturedRequests[2].url.path, '/test3');
    });

    test('capturedRequestsForHost filters by hostname', () async {
      mock = MockHttpClient(
        onRequest: (request) => request.respondWith(200, {}),
      );

      await mock.get(Uri.parse('https://main.realtime.ably.net/test'));
      await mock.get(Uri.parse('https://a.fallback.ably-realtime.com/test'));
      await mock.get(Uri.parse('https://main.realtime.ably.net/test2'));

      final ablyRequests =
          mock.capturedRequestsForHost('main.realtime.ably.net');
      expect(ablyRequests.length, 2);
      expect(ablyRequests[0].url.path, '/test');
      expect(ablyRequests[1].url.path, '/test2');

      final fallbackRequests =
          mock.capturedRequestsForHost('a.fallback.ably-realtime.com');
      expect(fallbackRequests.length, 1);
    });

    test('reset clears captured requests', () async {
      mock = MockHttpClient(
        onRequest: (request) => request.respondWith(200, {}),
      );

      await mock.get(Uri.parse('https://main.realtime.ably.net/test'));
      expect(mock.capturedRequests.length, 1);

      mock.reset();
      expect(mock.capturedRequests.length, 0);

      await mock.get(Uri.parse('https://main.realtime.ably.net/test2'));
      expect(mock.capturedRequests.length, 1);
    });

    test('CapturedRequest preserves all request details', () async {
      mock = MockHttpClient(
        onRequest: (request) => request.respondWith(200, {}),
      );

      await mock.post(
        Uri.parse('https://main.realtime.ably.net/channels/test/messages'),
        headers: {'X-Custom': 'value'},
        body: '{"test":"data"}',
      );

      final captured = mock.capturedRequests[0];
      expect(captured.method, 'POST');
      expect(captured.url.host, 'main.realtime.ably.net');
      expect(captured.url.path, '/channels/test/messages');
      expect(captured.headers['X-Custom'], 'value');
      expect(captured.body, '{"test":"data"}');
    });

    test('CapturedRequest jsonBody parses JSON', () async {
      mock = MockHttpClient(
        onRequest: (request) => request.respondWith(200, {}),
      );

      await mock.post(
        Uri.parse('https://main.realtime.ably.net/test'),
        body: '{"name":"test","value":123}',
      );

      final captured = mock.capturedRequests[0];
      final json = captured.jsonBody;
      expect(json['name'], 'test');
      expect(json['value'], 123);
    });
  });

  group('MockHttpClient - Default behavior', () {
    late MockHttpClient mock;

    tearDown(() {
      mock.dispose();
    });

    test('auto-succeeds connection attempts without handler', () async {
      mock = MockHttpClient(
        onRequest: (request) => request.respondWith(200, {}),
      );

      // Should succeed even without onConnectionAttempt handler
      final response =
          await mock.get(Uri.parse('https://main.realtime.ably.net/test'));
      expect(response.statusCode, 200);
    });

    test('auto-responds with 200 without request handler', () async {
      mock = MockHttpClient();

      // Should get default 200 response
      final response =
          await mock.get(Uri.parse('https://main.realtime.ably.net/test'));
      expect(response.statusCode, 200);
    });
  });

  group('MockHttpClient - Mixed handler and awaitable', () {
    late MockHttpClient mock;

    tearDown(() {
      mock.dispose();
    });

    test('handler and awaitable both receive events', () async {
      var handlerCalled = false;
      mock = MockHttpClient(
        onRequest: (request) {
          handlerCalled = true;
          request.respondWith(200, {});
        },
      );

      final requestFuture =
          mock.get(Uri.parse('https://main.realtime.ably.net/test'));
      final pendingRequest = await mock.awaitRequest();

      expect(handlerCalled, true);
      expect(pendingRequest.url.path, '/test');

      await requestFuture;
    });
  });
}
