import 'dart:convert';

import 'package:test/test.dart';
import 'package:ably_dart/ably_dart.dart';
import '../../../helpers/mock_http_client.dart';

/// Unit tests for REST channel updateMessage/deleteMessage/appendMessage
/// (RSL15a, RSL15b, RSL15b1, RSL15b7, RSL15c, RSL15d, RSL15e, RSL15f).
///
/// These tests use a mocked HTTP client to verify request formation
/// and response parsing for mutable message operations.
///
/// Spec: uts/test/rest/unit/channel/update_delete_message.md
void main() {
  group('RSL15b, RSL15b1 - updateMessage sends PATCH with MESSAGE_UPDATE', () {
    test('sends PATCH with action 1 to correct endpoint', () async {
      final channelName = 'test-RSL15-update';
      final mockHttp = MockHttpClient(
        onRequest: (request) {
          request.respondWith(200, {'versionSerial': 'vs1'});
        },
      );

      final client = Rest.forTesting(
        options: ClientOptions.fromKey('appId.keyId:keySecret'),
        httpClient: mockHttp,
      );

      final channel = client.channels.get(channelName);
      await channel.updateMessage(
        Message(serial: 'msg-serial-1', name: 'updated', data: 'new-data'),
      );

      expect(mockHttp.capturedRequests.length, equals(1));
      final request = mockHttp.capturedRequests[0];
      expect(request.method, equals('PATCH'));
      expect(
        request.url.path,
        equals(
          '/channels/${Uri.encodeComponent(channelName)}/messages/msg-serial-1',
        ),
      );

      final body = request.jsonBody as Map<String, dynamic>;
      expect(body['action'], equals(1));
      expect(body['name'], equals('updated'));
      expect(body['data'], equals('new-data'));

      mockHttp.dispose();
    });
  });

  group('RSL15b, RSL15b1 - deleteMessage sends PATCH with MESSAGE_DELETE', () {
    test('sends PATCH with action 2 to correct endpoint', () async {
      final channelName = 'test-RSL15-delete';
      final mockHttp = MockHttpClient(
        onRequest: (request) {
          request.respondWith(200, {'versionSerial': 'vs1'});
        },
      );

      final client = Rest.forTesting(
        options: ClientOptions.fromKey('appId.keyId:keySecret'),
        httpClient: mockHttp,
      );

      final channel = client.channels.get(channelName);
      await channel.deleteMessage(
        Message(serial: 'msg-serial-1'),
      );

      final request = mockHttp.capturedRequests[0];
      expect(request.method, equals('PATCH'));
      expect(
        request.url.path,
        equals(
          '/channels/${Uri.encodeComponent(channelName)}/messages/msg-serial-1',
        ),
      );

      final body = request.jsonBody as Map<String, dynamic>;
      expect(body['action'], equals(2));

      mockHttp.dispose();
    });
  });

  group('RSL15b, RSL15b1 - appendMessage sends PATCH with MESSAGE_APPEND', () {
    test('sends PATCH with action 5 to correct endpoint', () async {
      final channelName = 'test-RSL15-append';
      final mockHttp = MockHttpClient(
        onRequest: (request) {
          request.respondWith(200, {'versionSerial': 'vs1'});
        },
      );

      final client = Rest.forTesting(
        options: ClientOptions.fromKey('appId.keyId:keySecret'),
        httpClient: mockHttp,
      );

      final channel = client.channels.get(channelName);
      await channel.appendMessage(
        Message(serial: 'msg-serial-1', data: 'appended-data'),
      );

      final request = mockHttp.capturedRequests[0];
      expect(request.method, equals('PATCH'));
      expect(
        request.url.path,
        equals(
          '/channels/${Uri.encodeComponent(channelName)}/messages/msg-serial-1',
        ),
      );

      final body = request.jsonBody as Map<String, dynamic>;
      expect(body['action'], equals(5));
      expect(body['data'], equals('appended-data'));

      mockHttp.dispose();
    });
  });

  group('RSL15b7 - version set to MessageOperation when provided', () {
    test('includes version field with operation data', () async {
      final mockHttp = MockHttpClient(
        onRequest: (request) {
          request.respondWith(200, {'versionSerial': 'vs1'});
        },
      );

      final client = Rest.forTesting(
        options: ClientOptions.fromKey('appId.keyId:keySecret'),
        httpClient: mockHttp,
      );

      final channel = client.channels.get('test-RSL15b7');
      await channel.updateMessage(
        Message(serial: 's1', data: 'updated'),
        operation: MessageOperation(
          clientId: 'user1',
          description: 'fixed typo',
          metadata: {'reason': 'typo'},
        ),
      );

      final body =
          mockHttp.capturedRequests[0].jsonBody as Map<String, dynamic>;
      expect(body.containsKey('version'), isTrue);
      final version = body['version'] as Map<String, dynamic>;
      expect(version['clientId'], equals('user1'));
      expect(version['description'], equals('fixed typo'));
      expect((version['metadata'] as Map)['reason'], equals('typo'));

      mockHttp.dispose();
    });

    test('omits version field when no operation provided', () async {
      final mockHttp = MockHttpClient(
        onRequest: (request) {
          request.respondWith(200, {'versionSerial': 'vs1'});
        },
      );

      final client = Rest.forTesting(
        options: ClientOptions.fromKey('appId.keyId:keySecret'),
        httpClient: mockHttp,
      );

      final channel = client.channels.get('test-RSL15b7-absent');
      await channel.updateMessage(
        Message(serial: 's1', data: 'updated'),
      );

      final body =
          mockHttp.capturedRequests[0].jsonBody as Map<String, dynamic>;
      expect(body.containsKey('version'), isFalse);

      mockHttp.dispose();
    });
  });

  group('RSL15c - does not mutate user-supplied Message', () {
    test('original message is unchanged after updateMessage', () async {
      final mockHttp = MockHttpClient(
        onRequest: (request) {
          request.respondWith(200, {'versionSerial': 'vs1'});
        },
      );

      final client = Rest.forTesting(
        options: ClientOptions.fromKey('appId.keyId:keySecret'),
        httpClient: mockHttp,
      );

      final channel = client.channels.get('test-RSL15c');
      final originalMsg =
          Message(serial: 's1', name: 'orig', data: 'original-data');

      await channel.updateMessage(originalMsg);

      expect(originalMsg.action, isNull);
      expect(originalMsg.name, equals('orig'));
      expect(originalMsg.data, equals('original-data'));

      final body =
          mockHttp.capturedRequests[0].jsonBody as Map<String, dynamic>;
      expect(body['action'], equals(1));

      mockHttp.dispose();
    });
  });

  group('RSL15e - returns UpdateDeleteResult on success', () {
    test('parses versionSerial from response', () async {
      final mockHttp = MockHttpClient(
        onRequest: (request) {
          request.respondWith(200, {'versionSerial': 'version-serial-abc'});
        },
      );

      final client = Rest.forTesting(
        options: ClientOptions.fromKey('appId.keyId:keySecret'),
        httpClient: mockHttp,
      );

      final channel = client.channels.get('test-RSL15e');
      final result = await channel.updateMessage(
        Message(serial: 's1', data: 'updated'),
      );

      expect(result, isA<UpdateDeleteResult>());
      expect(result.versionSerial, equals('version-serial-abc'));

      mockHttp.dispose();
    });

    test('null versionSerial preserved', () async {
      final mockHttp = MockHttpClient(
        onRequest: (request) {
          request.respondWith(200, {'versionSerial': null});
        },
      );

      final client = Rest.forTesting(
        options: ClientOptions.fromKey('appId.keyId:keySecret'),
        httpClient: mockHttp,
      );

      final channel = client.channels.get('test-RSL15e-null');
      final result = await channel.updateMessage(
        Message(serial: 's1', data: 'updated'),
      );

      expect(result, isA<UpdateDeleteResult>());
      expect(result.versionSerial, isNull);

      mockHttp.dispose();
    });
  });

  group('RSL15f - params sent as querystring', () {
    test('optional params are sent as query parameters', () async {
      final mockHttp = MockHttpClient(
        onRequest: (request) {
          request.respondWith(200, {'versionSerial': 'vs1'});
        },
      );

      final client = Rest.forTesting(
        options: ClientOptions.fromKey('appId.keyId:keySecret'),
        httpClient: mockHttp,
      );

      final channel = client.channels.get('test-RSL15f');
      await channel.updateMessage(
        Message(serial: 's1', data: 'updated'),
        params: {'key': 'value', 'num': '42'},
      );

      final request = mockHttp.capturedRequests[0];
      expect(request.url.queryParameters['key'], equals('value'));
      expect(request.url.queryParameters['num'], equals('42'));

      mockHttp.dispose();
    });
  });

  group('RSL15a - serial required, throws error if missing', () {
    test('updateMessage without serial throws error code 40003', () async {
      final mockHttp = MockHttpClient(
        onRequest: (request) {
          request.respondWith(200, {'versionSerial': 'vs1'});
        },
      );

      final client = Rest.forTesting(
        options: ClientOptions.fromKey('appId.keyId:keySecret'),
        httpClient: mockHttp,
      );

      final channel = client.channels.get('test-RSL15a');

      try {
        await channel.updateMessage(Message(name: 'x', data: 'y'));
        fail('Expected AblyException');
      } catch (e) {
        expect(e, isA<AblyException>());
        expect((e as AblyException).errorInfo?.code, equals(40003));
      }

      try {
        await channel.deleteMessage(Message(name: 'x'));
        fail('Expected AblyException');
      } catch (e) {
        expect(e, isA<AblyException>());
        expect((e as AblyException).errorInfo?.code, equals(40003));
      }

      try {
        await channel.appendMessage(Message(data: 'y'));
        fail('Expected AblyException');
      } catch (e) {
        expect(e, isA<AblyException>());
        expect((e as AblyException).errorInfo?.code, equals(40003));
      }

      mockHttp.dispose();
    });
  });

  group('RSL15d - request body encoded per RSL4', () {
    test('JSON data encoded as string with encoding field', () async {
      final mockHttp = MockHttpClient(
        onRequest: (request) {
          request.respondWith(200, {'versionSerial': 'vs1'});
        },
      );

      final client = Rest.forTesting(
        options: ClientOptions.fromKey('appId.keyId:keySecret'),
        httpClient: mockHttp,
      );

      final channel = client.channels.get('test-RSL15d');
      await channel.updateMessage(
        Message(serial: 's1', data: {'key': 'value'}),
      );

      final body =
          mockHttp.capturedRequests[0].jsonBody as Map<String, dynamic>;
      expect(body['data'], isA<String>());
      expect(body['encoding'], equals('json'));
      expect(json.decode(body['data'] as String), equals({'key': 'value'}));

      mockHttp.dispose();
    });
  });

  group('RSL15b - serial URL-encoded in path', () {
    test('special characters in serial are URL-encoded', () async {
      final channelName = 'test-RSL15b-encode';
      const serialWithSpecialChars = 'serial/special:chars';

      final mockHttp = MockHttpClient(
        onRequest: (request) {
          request.respondWith(200, {'versionSerial': 'vs1'});
        },
      );

      final client = Rest.forTesting(
        options: ClientOptions.fromKey('appId.keyId:keySecret'),
        httpClient: mockHttp,
      );

      final channel = client.channels.get(channelName);
      await channel.updateMessage(
        Message(serial: serialWithSpecialChars, data: 'updated'),
      );

      final request = mockHttp.capturedRequests[0];
      expect(
        request.url.path,
        equals(
          '/channels/${Uri.encodeComponent(channelName)}/messages/${Uri.encodeComponent(serialWithSpecialChars)}',
        ),
      );

      mockHttp.dispose();
    });
  });
}
