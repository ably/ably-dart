import 'dart:convert';
import 'dart:typed_data';

import 'package:ably_dart/ably_dart.dart';
import 'package:test/test.dart';

import '../../../helpers/mock_http_client.dart';
import '../../../helpers/test_channel_name.dart';

/// Message Encoding Tests
///
/// Spec points: RSL4, RSL6 - Message encoding/decoding
void main() {
  group('Message Encoding', () {
    late MockHttpClient mockHttp;

    setUp(() {
      mockHttp = MockHttpClient();
    });

    group('RSL4 - Encoding messages for transmission', () {
      group('RSL4a - String data', () {
        // UTS: rest/unit/RSL4a/string-data-no-encoding-0
        test('transmits string data without encoding', () async {
          final capturedRequests = <CapturedRequest>[];
          final channelName = testChannelName('RSL4a');

          mockHttp = MockHttpClient(
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

          final client = Rest.forTesting(
            options: ClientOptions(
              key: 'appId.keyId:keySecret',
              useBinaryProtocol: false,
            ),
            httpClient: mockHttp,
          );
          final channel = client.channels.get(channelName);

          await channel.publish(name: 'event', data: 'hello world');

          final body = json.decode(capturedRequests[0].body!) as List;

          expect(body[0]['data'], equals('hello world'));
          expect(body[0].containsKey('encoding'), isFalse);
        });
      });

      group('RSL4c - JSON-encodable objects', () {
        // UTS: rest/unit/RSL4c/binary-base64-json-protocol-0
        test('encodes map data as JSON with encoding field', () async {
          final capturedRequests = <CapturedRequest>[];
          final channelName = testChannelName('RSL4c-map');

          mockHttp = MockHttpClient(
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

          final client = Rest.forTesting(
            options: ClientOptions(
              key: 'appId.keyId:keySecret',
              useBinaryProtocol: false,
            ),
            httpClient: mockHttp,
          );
          final channel = client.channels.get(channelName);

          await channel.publish(
            name: 'event',
            data: {'key': 'value', 'number': 42},
          );

          final body = json.decode(capturedRequests[0].body!) as List;

          expect(body[0]['encoding'], equals('json'));
          // Data should be JSON string
          final dataJson = json.decode(body[0]['data'] as String);
          expect(dataJson['key'], equals('value'));
          expect(dataJson['number'], equals(42));
        });

        // UTS: rest/unit/RSL4c/binary-direct-msgpack-protocol-1
        test('encodes list data as JSON', () async {
          final capturedRequests = <CapturedRequest>[];
          final channelName = testChannelName('RSL4c-list');

          mockHttp = MockHttpClient(
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

          final client = Rest.forTesting(
            options: ClientOptions(
              key: 'appId.keyId:keySecret',
              useBinaryProtocol: false,
            ),
            httpClient: mockHttp,
          );
          final channel = client.channels.get(channelName);

          await channel.publish(name: 'event', data: [1, 2, 3]);

          final body = json.decode(capturedRequests[0].body!) as List;

          expect(body[0]['encoding'], equals('json'));
        });
      });

      group('RSL4d - Binary data', () {
        // UTS: rest/unit/RSL4d/array-json-encoding-0
        test('encodes binary data as base64 for JSON protocol', () async {
          final capturedRequests = <CapturedRequest>[];
          final channelName = testChannelName('RSL4d');

          mockHttp = MockHttpClient(
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

          final client = Rest.forTesting(
            options: ClientOptions(
              key: 'appId.keyId:keySecret',
              useBinaryProtocol: false,
            ),
            httpClient: mockHttp,
          );
          final channel = client.channels.get(channelName);

          final binaryData = Uint8List.fromList([0x00, 0x01, 0xFF, 0xFE]);
          await channel.publish(name: 'event', data: binaryData);

          final body = json.decode(capturedRequests[0].body!) as List;

          expect(body[0]['encoding'], equals('base64'));
          // Verify it decodes back correctly
          final decoded = base64.decode(body[0]['data'] as String);
          expect(decoded, equals([0x00, 0x01, 0xFF, 0xFE]));
        });
      });
    });

    group('RSL6 - Decoding messages from server', () {
      group('RSL6a - Plain data (no encoding)', () {
        // UTS: rest/unit/RSL6a/decode-chained-encodings-2
        test('returns data unchanged when no encoding', () async {
          final channelName = testChannelName('RSL6a');
          mockHttp = MockHttpClient(
            onRequest: (req) {
              req.respondWith(200, [
                {'id': 'msg1', 'name': 'event', 'data': 'plain text'},
              ]);
            },
          );

          final client = Rest.forTesting(
            options: ClientOptions.fromKey('appId.keyId:keySecret'),
            httpClient: mockHttp,
          );
          final channel = client.channels.get(channelName);

          final result = await channel.history();

          expect(result.items[0].data, equals('plain text'));
          expect(result.items[0].encoding, isNull);
        });
      });

      group('RSL6b - JSON encoding', () {
        // UTS: rest/unit/RSL6b/unrecognized-encoding-preserved-0
        test('decodes JSON-encoded data to objects', () async {
          final channelName = testChannelName('RSL6b');
          mockHttp = MockHttpClient(
            onRequest: (req) {
              req.respondWith(200, [
                {
                  'id': 'msg1',
                  'name': 'event',
                  'data': '{"key":"value","number":42}',
                  'encoding': 'json',
                },
              ]);
            },
          );

          final client = Rest.forTesting(
            options: ClientOptions.fromKey('appId.keyId:keySecret'),
            httpClient: mockHttp,
          );
          final channel = client.channels.get(channelName);

          final result = await channel.history();

          final data = result.items[0].data as Map<String, dynamic>;
          expect(data['key'], equals('value'));
          expect(data['number'], equals(42));
          // Encoding should be consumed
          expect(result.items[0].encoding, isNull);
        });
      });

      group('RSL6c - Base64 encoding', () {
        // UTS: rest/unit/RSL6a/decode-base64-to-binary-0
        test('decodes base64-encoded data to binary', () async {
          final channelName = testChannelName('RSL6c');
          final originalBytes = [0x00, 0x01, 0xFF, 0xFE];
          final base64Data = base64.encode(originalBytes);

          mockHttp = MockHttpClient(
            onRequest: (req) {
              req.respondWith(200, [
                {
                  'id': 'msg1',
                  'name': 'event',
                  'data': base64Data,
                  'encoding': 'base64',
                },
              ]);
            },
          );

          final client = Rest.forTesting(
            options: ClientOptions.fromKey('appId.keyId:keySecret'),
            httpClient: mockHttp,
          );
          final channel = client.channels.get(channelName);

          final result = await channel.history();

          expect(result.items[0].data, isA<Uint8List>());
          expect(
            (result.items[0].data as Uint8List).toList(),
            equals(originalBytes),
          );
        });
      });

      group('RSL6 - Compound encoding', () {
        // UTS: rest/unit/RSL6/decode-utf8-base64-data-2
        test('decodes json/base64 encoded data', () async {
          final channelName = testChannelName('RSL6-compound');
          final jsonData = '{"nested":"object"}';
          final base64Data = base64.encode(utf8.encode(jsonData));

          mockHttp = MockHttpClient(
            onRequest: (req) {
              req.respondWith(200, [
                {
                  'id': 'msg1',
                  'name': 'event',
                  'data': base64Data,
                  'encoding': 'json/base64',
                },
              ]);
            },
          );

          final client = Rest.forTesting(
            options: ClientOptions.fromKey('appId.keyId:keySecret'),
            httpClient: mockHttp,
          );
          final channel = client.channels.get(channelName);

          final result = await channel.history();

          // Should decode base64 first, then parse JSON
          final data = result.items[0].data as Map<String, dynamic>;
          expect(data['nested'], equals('object'));
        });
      });
    });

    group('Encoding edge cases', () {
      // UTS: rest/unit/RSL4/empty-string-no-encoding-4
      test('handles empty string data', () async {
        final capturedRequests = <CapturedRequest>[];
        final channelName = testChannelName('RSL-empty-str');

        mockHttp = MockHttpClient(
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

        final client = Rest.forTesting(
          options: ClientOptions(
            key: 'appId.keyId:keySecret',
            useBinaryProtocol: false,
          ),
          httpClient: mockHttp,
        );
        final channel = client.channels.get(channelName);

        await channel.publish(name: 'event', data: '');

        final body = json.decode(capturedRequests[0].body!) as List;

        expect(body[0]['data'], equals(''));
        expect(body[0].containsKey('encoding'), isFalse);
      });

      // UTS: rest/unit/RSL4/empty-array-json-encoding-5
      test('handles empty binary data', () async {
        final capturedRequests = <CapturedRequest>[];
        final channelName = testChannelName('RSL-empty-bin');

        mockHttp = MockHttpClient(
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

        final client = Rest.forTesting(
          options: ClientOptions(
            key: 'appId.keyId:keySecret',
            useBinaryProtocol: false,
          ),
          httpClient: mockHttp,
        );
        final channel = client.channels.get(channelName);

        await channel.publish(name: 'event', data: Uint8List(0));

        final body = json.decode(capturedRequests[0].body!) as List;

        expect(body[0]['encoding'], equals('base64'));
        expect(body[0]['data'], equals('')); // Empty base64
      });

      // UTS: rest/unit/RSL4b/json-object-encoding-0
      test('handles deeply nested JSON objects', () async {
        final capturedRequests = <CapturedRequest>[];
        final channelName = testChannelName('RSL-nested');

        mockHttp = MockHttpClient(
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

        final client = Rest.forTesting(
          options: ClientOptions(
            key: 'appId.keyId:keySecret',
            useBinaryProtocol: false,
          ),
          httpClient: mockHttp,
        );
        final channel = client.channels.get(channelName);

        final nestedData = {
          'level1': {
            'level2': {
              'level3': {
                'value': 'deep',
              },
            },
          },
        };

        await channel.publish(name: 'event', data: nestedData);

        final body = json.decode(capturedRequests[0].body!) as List;

        expect(body[0]['encoding'], equals('json'));
        final parsedData = json.decode(body[0]['data'] as String);
        expect(
            parsedData['level1']['level2']['level3']['value'], equals('deep'));
      });
    });
  });
}
