import 'dart:convert';
import 'dart:typed_data';

import 'package:ably_dart/ably_dart.dart';
import 'package:test/test.dart';

import '../../helpers/mock_http_client.dart';

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
        test('transmits string data without encoding', () async {
          mockHttp.queueResponse(201, {'serials': ['s1']});

          final client = Rest(
            options: ClientOptions(
              key: 'appId.keyId:keySecret',
              useBinaryProtocol: false,
            ),
            httpClient: mockHttp,
          );
          final channel = client.channels.get('test');

          await channel.publish(name: 'event', data: 'hello world');

          final body = json.decode(mockHttp.capturedRequests[0].body!) as List;

          expect(body[0]['data'], equals('hello world'));
          expect(body[0].containsKey('encoding'), isFalse);
        });
      });

      group('RSL4c - JSON-encodable objects', () {
        test('encodes map data as JSON with encoding field', () async {
          mockHttp.queueResponse(201, {'serials': ['s1']});

          final client = Rest(
            options: ClientOptions(
              key: 'appId.keyId:keySecret',
              useBinaryProtocol: false,
            ),
            httpClient: mockHttp,
          );
          final channel = client.channels.get('test');

          await channel.publish(
            name: 'event',
            data: {'key': 'value', 'number': 42},
          );

          final body = json.decode(mockHttp.capturedRequests[0].body!) as List;

          expect(body[0]['encoding'], equals('json'));
          // Data should be JSON string
          final dataJson = json.decode(body[0]['data'] as String);
          expect(dataJson['key'], equals('value'));
          expect(dataJson['number'], equals(42));
        });

        test('encodes list data as JSON', () async {
          mockHttp.queueResponse(201, {'serials': ['s1']});

          final client = Rest(
            options: ClientOptions(
              key: 'appId.keyId:keySecret',
              useBinaryProtocol: false,
            ),
            httpClient: mockHttp,
          );
          final channel = client.channels.get('test');

          await channel.publish(name: 'event', data: [1, 2, 3]);

          final body = json.decode(mockHttp.capturedRequests[0].body!) as List;

          expect(body[0]['encoding'], equals('json'));
        });
      });

      group('RSL4d - Binary data', () {
        test('encodes binary data as base64 for JSON protocol', () async {
          mockHttp.queueResponse(201, {'serials': ['s1']});

          final client = Rest(
            options: ClientOptions(
              key: 'appId.keyId:keySecret',
              useBinaryProtocol: false,
            ),
            httpClient: mockHttp,
          );
          final channel = client.channels.get('test');

          final binaryData = Uint8List.fromList([0x00, 0x01, 0xFF, 0xFE]);
          await channel.publish(name: 'event', data: binaryData);

          final body = json.decode(mockHttp.capturedRequests[0].body!) as List;

          expect(body[0]['encoding'], equals('base64'));
          // Verify it decodes back correctly
          final decoded = base64.decode(body[0]['data'] as String);
          expect(decoded, equals([0x00, 0x01, 0xFF, 0xFE]));
        });
      });
    });

    group('RSL6 - Decoding messages from server', () {
      group('RSL6a - Plain data (no encoding)', () {
        test('returns data unchanged when no encoding', () async {
          mockHttp.queueResponse(200, [
            {'id': 'msg1', 'name': 'event', 'data': 'plain text'},
          ]);

          final client = Rest(
            options: ClientOptions.fromKey('appId.keyId:keySecret'),
            httpClient: mockHttp,
          );
          final channel = client.channels.get('test');

          final result = await channel.history();

          expect(result.items[0].data, equals('plain text'));
          expect(result.items[0].encoding, isNull);
        });
      });

      group('RSL6b - JSON encoding', () {
        test('decodes JSON-encoded data to objects', () async {
          mockHttp.queueResponse(200, [
            {
              'id': 'msg1',
              'name': 'event',
              'data': '{"key":"value","number":42}',
              'encoding': 'json',
            },
          ]);

          final client = Rest(
            options: ClientOptions.fromKey('appId.keyId:keySecret'),
            httpClient: mockHttp,
          );
          final channel = client.channels.get('test');

          final result = await channel.history();

          final data = result.items[0].data as Map<String, dynamic>;
          expect(data['key'], equals('value'));
          expect(data['number'], equals(42));
          // Encoding should be consumed
          expect(result.items[0].encoding, isNull);
        });
      });

      group('RSL6c - Base64 encoding', () {
        test('decodes base64-encoded data to binary', () async {
          final originalBytes = [0x00, 0x01, 0xFF, 0xFE];
          final base64Data = base64.encode(originalBytes);

          mockHttp.queueResponse(200, [
            {
              'id': 'msg1',
              'name': 'event',
              'data': base64Data,
              'encoding': 'base64',
            },
          ]);

          final client = Rest(
            options: ClientOptions.fromKey('appId.keyId:keySecret'),
            httpClient: mockHttp,
          );
          final channel = client.channels.get('test');

          final result = await channel.history();

          expect(result.items[0].data, isA<Uint8List>());
          expect(
            (result.items[0].data as Uint8List).toList(),
            equals(originalBytes),
          );
        });
      });

      group('RSL6 - Compound encoding', () {
        test('decodes json/base64 encoded data', () async {
          final jsonData = '{"nested":"object"}';
          final base64Data = base64.encode(utf8.encode(jsonData));

          mockHttp.queueResponse(200, [
            {
              'id': 'msg1',
              'name': 'event',
              'data': base64Data,
              'encoding': 'json/base64',
            },
          ]);

          final client = Rest(
            options: ClientOptions.fromKey('appId.keyId:keySecret'),
            httpClient: mockHttp,
          );
          final channel = client.channels.get('test');

          final result = await channel.history();

          // Should decode base64 first, then parse JSON
          final data = result.items[0].data as Map<String, dynamic>;
          expect(data['nested'], equals('object'));
        });
      });
    });

    group('Encoding edge cases', () {
      test('handles empty string data', () async {
        mockHttp.queueResponse(201, {'serials': ['s1']});

        final client = Rest(
          options: ClientOptions(
            key: 'appId.keyId:keySecret',
            useBinaryProtocol: false,
          ),
          httpClient: mockHttp,
        );
        final channel = client.channels.get('test');

        await channel.publish(name: 'event', data: '');

        final body = json.decode(mockHttp.capturedRequests[0].body!) as List;

        expect(body[0]['data'], equals(''));
        expect(body[0].containsKey('encoding'), isFalse);
      });

      test('handles empty binary data', () async {
        mockHttp.queueResponse(201, {'serials': ['s1']});

        final client = Rest(
          options: ClientOptions(
            key: 'appId.keyId:keySecret',
            useBinaryProtocol: false,
          ),
          httpClient: mockHttp,
        );
        final channel = client.channels.get('test');

        await channel.publish(name: 'event', data: Uint8List(0));

        final body = json.decode(mockHttp.capturedRequests[0].body!) as List;

        expect(body[0]['encoding'], equals('base64'));
        expect(body[0]['data'], equals('')); // Empty base64
      });

      test('handles deeply nested JSON objects', () async {
        mockHttp.queueResponse(201, {'serials': ['s1']});

        final client = Rest(
          options: ClientOptions(
            key: 'appId.keyId:keySecret',
            useBinaryProtocol: false,
          ),
          httpClient: mockHttp,
        );
        final channel = client.channels.get('test');

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

        final body = json.decode(mockHttp.capturedRequests[0].body!) as List;

        expect(body[0]['encoding'], equals('json'));
        final parsedData = json.decode(body[0]['data'] as String);
        expect(parsedData['level1']['level2']['level3']['value'], equals('deep'));
      });
    });
  });
}
