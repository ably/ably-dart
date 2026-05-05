import 'dart:convert';
import 'dart:typed_data';

import 'package:ably_dart/ably_dart.dart';
import 'package:test/test.dart';

/// Message Types Tests
///
/// Spec points: TM1, TM2, TM3, TM4, TM2a, TM2b, TM2c, TM2d, TM2e,
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

    group('TM3 - fromEncoded / fromEncodedArray', () {
      test('fromEncoded deserializes wire format', () {
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

      test('fromEncoded decodes null encoding (plain text)', () {
        final message = Message.fromJson({
          'id': 'msg',
          'name': 'event',
          'data': 'plain text',
          'encoding': null,
        });
        expect(message.data, equals('plain text'));
      });

      test('fromEncoded decodes json encoding', () {
        final message = Message.fromJson({
          'id': 'msg',
          'name': 'event',
          'data': '{"key":"value"}',
          'encoding': 'json',
        });
        expect(message.data, equals({'key': 'value'}));
      });

      test('fromEncoded decodes base64 encoding', () {
        final message = Message.fromJson({
          'id': 'msg',
          'name': 'event',
          'data': base64.encode(utf8.encode('Hello')),
          'encoding': 'base64',
        });
        expect(message.data, isA<Uint8List>());
        expect(utf8.decode(message.data as Uint8List), equals('Hello'));
      });

      test('fromEncoded decodes json/base64 compound encoding', () {
        final message = Message.fromJson({
          'id': 'msg',
          'name': 'event',
          'data': base64.encode(utf8.encode('{"k":"v"}')),
          'encoding': 'json/base64',
        });
        expect(message.data, equals({'k': 'v'}));
      });

      test('fromEncodedArray deserializes array of messages', () {
        final messages = Message.fromEncodedArray([
          {'name': 'event1', 'data': 'data1'},
          {'name': 'event2', 'data': 'data2'},
        ]);
        expect(messages.length, equals(2));
        expect(messages[0].name, equals('event1'));
        expect(messages[1].name, equals('event2'));
      });
    });

    group('TM4 - Message constructors', () {
      test('constructor(name, data)', () {
        final message = Message(name: 'event-name', data: 'payload');
        expect(message.name, equals('event-name'));
        expect(message.data, equals('payload'));
        expect(message.clientId, isNull);
      });

      test('constructor(name, data, clientId)', () {
        final message = Message(
          name: 'event-name',
          data: 'payload',
          clientId: 'client-1',
        );
        expect(message.name, equals('event-name'));
        expect(message.data, equals('payload'));
        expect(message.clientId, equals('client-1'));
      });

      test('name and data are nullable', () {
        final message = Message();
        expect(message.name, isNull);
        expect(message.data, isNull);
      });
    });

    group('TM - Null/missing attributes', () {
      test('null or missing attributes are handled correctly', () {
        final message = Message();

        expect(message.id, isNull);
        expect(message.name, isNull);
        expect(message.data, isNull);
        expect(message.clientId, isNull);
        expect(message.timestamp, isNull);
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

        expect(
          message.extras?.data['push']['notification']['title'],
          equals('New Message'),
        );
        expect(
          message.extras?.data['push']['data']['customKey'],
          equals('customValue'),
        );
      });
    });
  });
}
