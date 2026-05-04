import 'dart:convert';
import 'dart:typed_data';

import 'package:ably_dart/ably_dart.dart';
import 'package:test/test.dart';

/// Message Types Tests
///
/// Spec points: TM1, TM2, TM3, TM4, TM5, TM2a, TM2b, TM2c, TM2d, TM2e,
///              TM2f, TM2g, TM2h, TM2i
void main() {
  group('Message', () {
    group('TM2a-TM2i - Message attributes', () {
      test('TM2a - id attribute', () {
        final message = Message(id: 'unique-id');
        expect(message.id, equals('unique-id'));
      });

      test('TM2b - name attribute', () {
        final message = Message(name: 'event-name');
        expect(message.name, equals('event-name'));
      });

      test('TM2c - data attribute (string)', () {
        final message = Message(data: 'string-data');
        expect(message.data, equals('string-data'));
      });

      test('TM2c - data attribute (map)', () {
        final message = Message(data: {'key': 'value'});
        expect(message.data, equals({'key': 'value'}));
      });

      test('TM2c - data attribute (binary)', () {
        final bytes = Uint8List.fromList([0x01, 0x02]);
        final message = Message(data: bytes);
        expect(message.data, equals(bytes));
      });

      test('TM2d - clientId attribute', () {
        final message = Message(clientId: 'message-client');
        expect(message.clientId, equals('message-client'));
      });

      test('TM2e - connectionId attribute', () {
        final message = Message(connectionId: 'conn-id');
        expect(message.connectionId, equals('conn-id'));
      });

      test('TM2f - timestamp attribute', () {
        final message = Message(timestamp: 1234567890000);
        expect(message.timestamp, equals(1234567890000));
      });

      test('TM2g - encoding attribute', () {
        final message = Message(encoding: 'json/base64');
        expect(message.encoding, equals('json/base64'));
      });

      test('TM2h - extras attribute', () {
        final message = Message(
          extras: MessageExtras(data: {
            'push': {
              'notification': {'title': 'Hello'},
            },
          }),
        );
        expect(message.extras?.data['push']['notification']['title'],
            equals('Hello'));
      });
    });

    group('TM3 - Message from JSON (wire format)', () {
      test('deserializes from JSON wire format', () {
        final jsonData = {
          'id': 'msg-123',
          'name': 'test-event',
          'data': 'hello world',
          'clientId': 'sender-client',
          'connectionId': 'conn-456',
          'timestamp': 1234567890000,
          'encoding': null,
          'extras': {
            'headers': {'x-custom': 'value'},
          },
        };

        final message = Message.fromJson(jsonData);

        expect(message.id, equals('msg-123'));
        expect(message.name, equals('test-event'));
        expect(message.data, equals('hello world'));
        expect(message.clientId, equals('sender-client'));
        expect(message.connectionId, equals('conn-456'));
        expect(message.timestamp, equals(1234567890000));
        expect(message.extras?.data['headers']['x-custom'], equals('value'));
      });
    });

    group('TM3 - Message with encoded data from JSON', () {
      test('handles null encoding (plain text)', () {
        final jsonData = {
          'id': 'msg',
          'name': 'event',
          'data': 'plain text',
          'encoding': null,
        };

        final message = Message.fromJson(jsonData);
        expect(message.data, equals('plain text'));
      });

      test('handles json encoding', () {
        final jsonData = {
          'id': 'msg',
          'name': 'event',
          'data': '{"key":"value"}',
          'encoding': 'json',
        };

        final message = Message.fromJson(jsonData);
        // After decoding, data should be the parsed object
        expect(message.data, equals({'key': 'value'}));
      });

      test('handles base64 encoding', () {
        final jsonData = {
          'id': 'msg',
          'name': 'event',
          'data': base64.encode(utf8.encode('Hello')),
          'encoding': 'base64',
        };

        final message = Message.fromJson(jsonData);
        // After decoding, data should be bytes
        expect(message.data, isA<Uint8List>());
        expect(utf8.decode(message.data as Uint8List), equals('Hello'));
      });

      test('handles json/base64 encoding', () {
        final jsonData = {
          'id': 'msg',
          'name': 'event',
          'data': base64.encode(utf8.encode('{"k":"v"}')),
          'encoding': 'json/base64',
        };

        final message = Message.fromJson(jsonData);
        expect(message.data, equals({'k': 'v'}));
      });
    });

    group('TM4 - Message to JSON (wire format)', () {
      test('serializes correctly for transmission', () {
        final message = Message(
          id: 'custom-id',
          name: 'outgoing-event',
          data: 'outgoing-data',
          clientId: 'sending-client',
        );

        final jsonData = message.toJson();

        expect(jsonData['id'], equals('custom-id'));
        expect(jsonData['name'], equals('outgoing-event'));
        expect(jsonData['data'], equals('outgoing-data'));
        expect(jsonData['clientId'], equals('sending-client'));
      });
    });

    group('TM4 - Message with object data to JSON', () {
      test('object data is JSON-encoded for transmission', () {
        final message = Message(
          name: 'json-event',
          data: {
            'nested': {
              'array': [1, 2, 3],
            },
          },
        );

        final jsonData = message.toJson();

        // Object should be JSON-encoded with encoding field set
        expect(jsonData['encoding'], equals('json'));
      });
    });

    group('TM4 - Message with binary data to JSON', () {
      test('binary data is base64-encoded for JSON transmission', () {
        final message = Message(
          name: 'binary-event',
          data: Uint8List.fromList([0x00, 0x01, 0xFF]),
        );

        final jsonData = message.toJson();

        expect(jsonData['encoding'], equals('base64'));
        expect(
          base64.decode(jsonData['data'] as String),
          equals([0x00, 0x01, 0xFF]),
        );
      });
    });

    group('TM5 - Message equality', () {
      test('messages with same content are equal', () {
        final message1 = Message(id: 'same-id', name: 'event', data: 'data');
        final message2 = Message(id: 'same-id', name: 'event', data: 'data');
        final message3 =
            Message(id: 'different-id', name: 'event', data: 'data');

        expect(message1, equals(message2));
        expect(message1, isNot(equals(message3)));
      });
    });

    group('TM - Message with extras', () {
      test('push notification extras are handled correctly', () {
        final message = Message(
          name: 'push-event',
          data: 'payload',
          extras: MessageExtras(data: {
            'push': {
              'notification': {
                'title': 'New Message',
                'body': 'You have a new notification',
              },
              'data': {
                'customKey': 'customValue',
              },
            },
          }),
        );

        final jsonData = message.toJson();

        expect(
          jsonData['extras']['push']['notification']['title'],
          equals('New Message'),
        );
        expect(
          jsonData['extras']['push']['data']['customKey'],
          equals('customValue'),
        );
      });
    });

    group('TM - Null/missing attributes', () {
      test('null or missing attributes are handled correctly', () {
        // Minimal message
        final message = Message();

        // All optional attributes should be null
        expect(message.id, isNull);
        expect(message.name, isNull);
        expect(message.data, isNull);
        expect(message.clientId, isNull);
        expect(message.timestamp, isNull);

        // Serialization should omit null fields
        final jsonData = message.toJson();
        expect(jsonData.containsKey('id'), isFalse);
        expect(jsonData.containsKey('name'), isFalse);
        expect(jsonData.containsKey('data'), isFalse);
      });
    });
  });
}
