import 'package:ably_dart/ably_dart.dart';
import 'package:test/test.dart';

import '../../helpers/mock_http_client.dart';

/// Stats API Tests
///
/// Spec points: RSC6
///
/// NOTE: These tests are currently disabled because the stats() API is not yet
/// implemented in ably-dart. Once the following are implemented, these tests
/// should pass:
/// - Rest.stats() method
/// - Stats model class
/// - StatsIntervalGranularity enum
/// - PaginatedResult<Stats> support
///
/// To enable tests when ready, uncomment the test body and run:
/// dart test test/unit/client/stats_test.dart
void main() {
  group('Stats API', () {
    late MockHttpClient mockHttp;

    setUp(() {
      mockHttp = MockHttpClient();
    });

    group('RSC6a - stats() returns paginated results', () {
      /// RSC6a - stats() returns paginated results
      ///
      /// The stats() method retrieves application statistics from the /stats
      /// endpoint and returns a PaginatedResult of Stats objects.
      test('returns PaginatedResult of Stats objects', () async {
        final statsData = [
          {
            'intervalId': '2024-01-01:00:00',
            'unit': 'hour',
            'all': {
              'messages': {'count': 100, 'data': 5000},
              'all': {'count': 100, 'data': 5000},
            },
          },
          {
            'intervalId': '2024-01-01:01:00',
            'unit': 'hour',
            'all': {
              'messages': {'count': 150, 'data': 7500},
              'all': {'count': 150, 'data': 7500},
            },
          },
        ];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(200, statsData);
          },
        );

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final result = await client.stats();

        // Result should be a PaginatedResult
        expect(result, isA<PaginatedResult<Stats>>());
        expect(result.items.length, equals(2));

        // First stats object
        expect(result.items[0].intervalId, equals('2024-01-01:00:00'));
        expect(result.items[0].unit, equals(StatsIntervalGranularity.hour));

        // Verify correct endpoint was called
        expect(mockHttp.capturedRequests.length, equals(1));
        final request = mockHttp.capturedRequests[0];
        expect(request.method, equals('GET'));
        expect(request.url.path, equals('/stats'));
      });
    });

    group('RSC6a - stats() requires authentication', () {
      /// RSC6a - stats() requires authentication
      ///
      /// The /stats endpoint requires authentication. Requests must include
      /// valid credentials.
      test('includes Authorization header', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(200, []);
          },
        );

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.stats();

        expect(mockHttp.capturedRequests.length, equals(1));
        final request = mockHttp.capturedRequests[0];

        // Request should have Authorization header
        expect(request.headers.containsKey('Authorization'), isTrue);
      });
    });

    group('RSC6b1 - stats() with start parameter', () {
      /// RSC6b1 - stats() with start parameter
      ///
      /// The start parameter filters stats to return entries from the
      /// specified start time onwards.
      test('filters stats by start time', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(200, []);
          },
        );

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final startTime = DateTime.utc(2024, 1, 1, 0, 0, 0);
        await client.stats(start: startTime);

        expect(mockHttp.capturedRequests.length, equals(1));
        final request = mockHttp.capturedRequests[0];
        expect(
          request.url.queryParameters['start'],
          equals(startTime.millisecondsSinceEpoch.toString()),
        );
      });
    });

    group('RSC6b1 - stats() with end parameter', () {
      /// RSC6b1 - stats() with end parameter
      ///
      /// The end parameter filters stats to return entries up to the
      /// specified end time.
      test('filters stats by end time', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(200, []);
          },
        );

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final endTime = DateTime.utc(2024, 1, 31, 23, 59, 59);
        await client.stats(end: endTime);

        expect(mockHttp.capturedRequests.length, equals(1));
        final request = mockHttp.capturedRequests[0];
        expect(
          request.url.queryParameters['end'],
          equals(endTime.millisecondsSinceEpoch.toString()),
        );
      });
    });

    group('RSC6b2 - stats() with limit parameter', () {
      /// RSC6b2 - stats() with limit parameter
      ///
      /// The limit parameter restricts the number of stats entries returned
      /// in a single page.
      test('restricts number of results', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(200, []);
          },
        );

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.stats(limit: 10);

        expect(mockHttp.capturedRequests.length, equals(1));
        final request = mockHttp.capturedRequests[0];
        expect(request.url.queryParameters['limit'], equals('10'));
      });
    });

    group('RSC6b3 - stats() with direction parameter', () {
      /// RSC6b3 - stats() with direction parameter
      ///
      /// The direction parameter controls the ordering of results (forwards
      /// or backwards in time).
      test('controls result ordering with forwards direction', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(200, []);
          },
        );

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        // Test forwards direction
        await client.stats(direction: 'forwards');

        expect(mockHttp.capturedRequests.length, equals(1));
        final request = mockHttp.capturedRequests[0];
        expect(request.url.queryParameters['direction'], equals('forwards'));
      });

      test('controls result ordering with backwards direction', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(200, []);
          },
        );

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        // Test backwards direction (default)
        await client.stats(direction: 'backwards');

        expect(mockHttp.capturedRequests.length, equals(1));
        final request = mockHttp.capturedRequests[0];
        expect(request.url.queryParameters['direction'], equals('backwards'));
      });
    });

    group('RSC6b4 - stats() with unit parameter', () {
      /// RSC6b4 - stats() with unit parameter
      ///
      /// The unit parameter specifies the time granularity for stats
      /// aggregation (minute, hour, day, or month).
      test('specifies stats granularity with day unit', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(200, []);
          },
        );

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        // Valid units: minute, hour, day, month
        await client.stats(unit: StatsIntervalGranularity.day);

        expect(mockHttp.capturedRequests.length, equals(1));
        final request = mockHttp.capturedRequests[0];
        expect(request.url.queryParameters['unit'], equals('day'));
      });

      test('specifies stats granularity with hour unit', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(200, []);
          },
        );

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.stats(unit: StatsIntervalGranularity.hour);

        expect(mockHttp.capturedRequests.length, equals(1));
        final request = mockHttp.capturedRequests[0];
        expect(request.url.queryParameters['unit'], equals('hour'));
      });

      test('specifies stats granularity with minute unit', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(200, []);
          },
        );

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.stats(unit: StatsIntervalGranularity.minute);

        expect(mockHttp.capturedRequests.length, equals(1));
        final request = mockHttp.capturedRequests[0];
        expect(request.url.queryParameters['unit'], equals('minute'));
      });

      test('specifies stats granularity with month unit', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(200, []);
          },
        );

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.stats(unit: StatsIntervalGranularity.month);

        expect(mockHttp.capturedRequests.length, equals(1));
        final request = mockHttp.capturedRequests[0];
        expect(request.url.queryParameters['unit'], equals('month'));
      });
    });

    group('RSC6a - stats() pagination navigation', () {
      /// RSC6a - stats() pagination navigation
      ///
      /// Stats results must support pagination using Link headers and provide
      /// hasNext() functionality.
      test('supports pagination navigation', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(
              200,
              [
                {'intervalId': '2024-01-01:00:00', 'unit': 'hour'},
              ],
              headers: {'link': '</stats?start=...&limit=1>; rel="next"'},
            );
          },
        );

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final page1 = await client.stats(limit: 1);

        expect(page1.items.length, equals(1));
        expect(page1.hasNext(), isTrue);
      });
    });

    group('RSC6a - stats() empty results', () {
      /// RSC6a - stats() empty results
      ///
      /// The stats() method must handle empty result sets correctly.
      test('handles empty results correctly', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(200, []);
          },
        );

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final result = await client.stats();

        expect(result.items, isA<List>());
        expect(result.items.length, equals(0));
        expect(result.hasNext(), isFalse);
        expect(result.isLast(), isTrue);
      });
    });

    group('RSC6a - stats() error handling', () {
      /// RSC6a - stats() error handling
      ///
      /// Errors from the stats endpoint must be properly propagated to
      /// the caller.
      test('properly propagates errors from stats endpoint', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(401, {
              'error': {
                'message': 'Unauthorized',
                'code': 40100,
                'statusCode': 401,
              },
            });
          },
        );

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        expect(
          () => client.stats(),
          throwsA(
            isA<AblyException>()
                .having((e) => e.statusCode, 'statusCode', equals(401))
                .having((e) => e.code, 'code', equals(40100)),
          ),
        );
      });
    });
  });
}
