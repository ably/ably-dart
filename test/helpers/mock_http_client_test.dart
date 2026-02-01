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
            request.respondWith(404, {'error': {'code': 40400}});
          }
        },
      );

      // Make a request
      final response = await mock.get(Uri.parse('https://rest.ably.io/time'));

      expect(response.statusCode, 200);
      expect(mock.capturedRequests.length, 1);
      expect(mock.capturedRequests[0].url.path, '/time');
    });

    test('connection attempt handling', () async {
      mock = MockHttpClient(
        onConnectionAttempt: (connection) {
          expect(connection.host, 'rest.ably.io');
          expect(connection.tls, true);
          connection.respondWithSuccess();
        },
        onRequest: (request) {
          request.respondWith(200, {'success': true});
        },
      );

      final response = await mock.get(Uri.parse('https://rest.ably.io/test'));
      expect(response.statusCode, 200);
    });

    test('connection refused simulation', () async {
      mock = MockHttpClient(
        onConnectionAttempt: (connection) {
          connection.respondWithRefused();
        },
      );

      expect(
        () => mock.get(Uri.parse('https://rest.ably.io/test')),
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
        () => mock.get(Uri.parse('https://rest.ably.io/test')),
        throwsA(isA<Exception>()),
      );
    });

    test('awaitable request', () async {
      mock = MockHttpClient();

      // Start a request in the background
      final requestFuture = mock.get(Uri.parse('https://rest.ably.io/test'));

      // Await the request in test code
      final pendingRequest = await mock.awaitRequest();

      expect(pendingRequest.url.path, '/test');
      expect(pendingRequest.method, 'GET');

      // Respond to it
      pendingRequest.respondWith(200, {'data': 'test'});

      final response = await requestFuture;
      expect(response.statusCode, 200);
    });

    test('PendingRequest body parsing', () async {
      mock = MockHttpClient(
        onRequest: (request) {
          if (request.body.isNotEmpty) {
            final json = request.jsonBody;
            expect(json['name'], 'event');
            expect(json['data'], 'payload');
          }
          request.respondWith(200, {'success': true});
        },
      );

      await mock.post(
        Uri.parse('https://rest.ably.io/channels/test/messages'),
        body: '{"name":"event","data":"payload"}',
      );
    });

    test('delayed response', () async {
      mock = MockHttpClient(
        onRequest: (request) {
          request.respondWithDelay(
            Duration(milliseconds: 10),
            200,
            {'delayed': true},
          );
        },
      );

      final stopwatch = Stopwatch()..start();
      final response = await mock.get(Uri.parse('https://rest.ably.io/test'));
      stopwatch.stop();

      expect(response.statusCode, 200);
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(10));
    });
  });

  group('MockHttpClient - Backward compatibility', () {
    test('queue-based responses still work', () async {
      final mock = MockHttpClient();

      // Old pattern: queue responses
      mock.queueResponse(200, {'time': 1234567890000});

      final response = await mock.get(Uri.parse('https://rest.ably.io/time'));
      expect(response.statusCode, 200);

      mock.dispose();
    });

    test('host-specific queued responses', () async {
      final mock = MockHttpClient();

      mock.queueResponseForHost('rest.ably.io', 200, {'success': true});
      mock.queueResponseForHost('other.com', 404, {'error': 'not found'});

      final response1 = await mock.get(Uri.parse('https://rest.ably.io/test'));
      expect(response1.statusCode, 200);

      final response2 = await mock.get(Uri.parse('https://other.com/test'));
      expect(response2.statusCode, 404);

      mock.dispose();
    });

    test('queued errors still work', () async {
      final mock = MockHttpClient();

      mock.queueNetworkError('Connection refused');

      expect(
        () => mock.get(Uri.parse('https://rest.ably.io/test')),
        throwsA(isA<Exception>()),
      );

      mock.dispose();
    });
  });

  group('MockHttpClient - Priority', () {
    test('handler responses take priority over queued responses', () async {
      final mock = MockHttpClient(
        onRequest: (request) {
          request.respondWith(201, {'handler': true});
        },
      );

      // Queue a response (should be ignored)
      mock.queueResponse(200, {'queued': true});

      final response = await mock.get(Uri.parse('https://rest.ably.io/test'));

      // Handler response takes priority
      expect(response.statusCode, 201);

      // Queued response is not consumed
      expect(mock.capturedRequests.length, 1);

      mock.dispose();
    });
  });
}
