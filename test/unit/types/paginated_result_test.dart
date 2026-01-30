import 'package:ably_dart/ably_dart.dart';
import 'package:test/test.dart';

import '../../helpers/mock_http_client.dart';

/// PaginatedResult Types Tests
///
/// Spec points: TG1, TG2, TG3, TG4
void main() {
  group('PaginatedResult', () {
    late MockHttpClient mockHttp;

    setUp(() {
      mockHttp = MockHttpClient();
    });

    group('TG1 - PaginatedResult items attribute', () {
      test('contains items array', () async {
        mockHttp.queueResponse(
          200,
          [
            {'id': 'item1', 'name': 'e1', 'data': 'd1'},
            {'id': 'item2', 'name': 'e2', 'data': 'd2'},
          ],
        );

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );
        final channel = client.channels.get('test');

        final result = await channel.history();

        expect(result.items, isList);
        expect(result.items.length, equals(2));
        expect(result.items[0].id, equals('item1'));
        expect(result.items[1].id, equals('item2'));
      });
    });

    group('TG2 - hasNext() and isLast() methods', () {
      test('returns true when more pages exist', () async {
        mockHttp.queueResponse(
          200,
          [
            {'id': 'item1'},
          ],
          headers: {
            'Link': '</channels/test/messages?cursor=next123>; rel="next"',
          },
        );

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );
        final channel = client.channels.get('test');

        final result = await channel.history();

        expect(result.hasNext(), isTrue);
        expect(result.isLast(), isFalse);
      });

      test('returns false when no more pages', () async {
        mockHttp.queueResponse(
          200,
          [
            {'id': 'item1'},
          ],
          headers: {},
        );

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );
        final channel = client.channels.get('test');

        final result = await channel.history();

        expect(result.hasNext(), isFalse);
        expect(result.isLast(), isTrue);
      });
    });

    group('TG3 - next() method', () {
      test('fetches the next page of results', () async {
        // First page
        mockHttp.queueResponse(
          200,
          [
            {'id': 'page1-item1'},
            {'id': 'page1-item2'},
          ],
          headers: {
            'Link': '</channels/test/messages?cursor=abc123>; rel="next"',
          },
        );
        // Second page
        mockHttp.queueResponse(
          200,
          [
            {'id': 'page2-item1'},
          ],
          headers: {},
        );

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );
        final channel = client.channels.get('test');

        final page1 = await channel.history();
        final page2 = await page1.next();

        // First page
        expect(page1.items.length, equals(2));
        expect(page1.items[0].id, equals('page1-item1'));
        expect(page1.hasNext(), isTrue);

        // Second page
        expect(page2, isNotNull);
        expect(page2!.items.length, equals(1));
        expect(page2.items[0].id, equals('page2-item1'));
        expect(page2.hasNext(), isFalse);

        // Verify next request used cursor from Link header
        final nextRequest = mockHttp.capturedRequests[1];
        expect(nextRequest.url.queryParameters['cursor'], equals('abc123'));
      });
    });

    group('TG4 - first() method', () {
      test('returns to the first page', () async {
        // Initial request
        mockHttp.queueResponse(
          200,
          [
            {'id': 'item1'},
          ],
          headers: {
            'Link':
                '</channels/test/messages?cursor=next>; rel="next", </channels/test/messages>; rel="first"',
          },
        );
        // Next page
        mockHttp.queueResponse(
          200,
          [
            {'id': 'item2'},
          ],
          headers: {
            'Link': '</channels/test/messages>; rel="first"',
          },
        );
        // First page again
        mockHttp.queueResponse(
          200,
          [
            {'id': 'item1'},
          ],
          headers: {
            'Link': '</channels/test/messages?cursor=next>; rel="next"',
          },
        );

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );
        final channel = client.channels.get('test');

        final page1 = await channel.history();
        final page2 = await page1.next();
        final firstPage = await page2!.first();

        expect(firstPage.items[0].id, equals('item1'));
      });
    });

    group('TG - Empty result', () {
      test('handles empty results correctly', () async {
        mockHttp.queueResponse(200, [], headers: {});

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );
        final channel = client.channels.get('test');

        final result = await channel.history();

        expect(result.items, isList);
        expect(result.items.length, equals(0));
        expect(result.hasNext(), isFalse);
        expect(result.isLast(), isTrue);
      });
    });

    group('TG - Link header parsing', () {
      final testCases = [
        (
          linkHeader: '</path?cursor=abc>; rel="next"',
          expectedHasNext: true,
          description: 'simple next link',
        ),
        (
          linkHeader:
              '</path?cursor=abc>; rel="next", </path>; rel="first"',
          expectedHasNext: true,
          description: 'next and first links',
        ),
        (
          linkHeader: '</path>; rel="first"',
          expectedHasNext: false,
          description: 'only first link',
        ),
        (
          linkHeader: null,
          expectedHasNext: false,
          description: 'no Link header',
        ),
      ];

      for (final testCase in testCases) {
        test('parses ${testCase.description}', () async {
          mockHttp.queueResponse(
            200,
            [
              {'id': 'item'},
            ],
            headers: testCase.linkHeader != null
                ? {'Link': testCase.linkHeader!}
                : {},
          );

          final client = Rest(
            options: ClientOptions.fromKey('appId.keyId:keySecret'),
            httpClient: mockHttp,
          );
          final result = await client.channels.get('test').history();

          expect(result.hasNext(), equals(testCase.expectedHasNext));
        });
      }
    });

    group('TG - PaginatedResult type parameter', () {
      test('items are correctly typed as Message', () async {
        mockHttp.queueResponse(
          200,
          [
            {'id': 'msg1', 'name': 'event', 'data': 'test'},
          ],
        );

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );
        final channel = client.channels.get('test');

        final historyResult = await channel.history();

        expect(historyResult.items[0], isA<Message>());
      });
    });

    group('TG - next() on last page', () {
      test('returns null when calling next on last page', () async {
        mockHttp.queueResponse(
          200,
          [
            {'id': 'item'},
          ],
          headers: {},
        );

        final client = Rest(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );
        final channel = client.channels.get('test');

        final result = await channel.history();
        expect(result.isLast(), isTrue);

        final nextResult = await result.next();

        // Implementation may return null or empty PaginatedResult
        expect(
          nextResult == null || nextResult.items.isEmpty,
          isTrue,
        );
      });
    });
  });
}
