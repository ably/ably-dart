import 'dart:convert';

import 'package:ably_dart/ably_dart.dart';
import 'package:test/test.dart';

import '../../helpers/mock_http_client.dart';

/// Batch Publish Tests
///
/// Spec points: RSC22, BSP2, BPR2, BPF2
void main() {
  group('Batch Publish', () {
    late MockHttpClient mockHttp;

    setUp(() {
      mockHttp = MockHttpClient();
    });

    group('RSC22c - Request format', () {
      test('RSC22c1 - Single BatchPublishSpec sends POST to /messages',
          () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(201, [
              {
                'channel': 'channel1',
                'messageId': 'msg1',
                'serials': ['s1']
              },
            ]);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.batchPublish(
          BatchPublishSpec(
            channels: ['channel1'],
            messages: [Message(name: 'event', data: 'data')],
          ),
        );

        final request = capturedRequests[0];
        expect(request.method, equals('POST'));
        expect(request.url.path, equals('/messages'));
      });

      test('RSC22c2 - Array of BatchPublishSpecs sends POST to /messages',
          () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(201, [
              {'channel': 'channel1', 'messageId': 'msg1'},
              {'channel': 'channel2', 'messageId': 'msg2'},
            ]);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.batchPublish([
          BatchPublishSpec(
            channels: ['channel1'],
            messages: [Message(name: 'event1')],
          ),
          BatchPublishSpec(
            channels: ['channel2'],
            messages: [Message(name: 'event2')],
          ),
        ]);

        final request = capturedRequests[0];
        expect(request.method, equals('POST'));
        expect(request.url.path, equals('/messages'));

        // Body should be an array
        final body = json.decode(request.body!) as List;
        expect(body.length, equals(2));
      });

      test('RSC22c3 - Single spec returns single BatchResult', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(201, [
              {
                'channel': 'channel1',
                'messageId': 'msg1',
                'serials': ['s1']
              },
            ]);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final results = await client.batchPublish(
          BatchPublishSpec(
            channels: ['channel1'],
            messages: [Message(name: 'event')],
          ),
        );

        expect(results.length, equals(1));
        expect(results[0].channel, equals('channel1'));
      });

      test('RSC22c4 - Array of specs returns array of BatchResults', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(201, [
              {'channel': 'channel1', 'messageId': 'msg1'},
              {'channel': 'channel2', 'messageId': 'msg2'},
            ]);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final results = await client.batchPublish([
          BatchPublishSpec(
            channels: ['channel1'],
            messages: [Message(name: 'event1')],
          ),
          BatchPublishSpec(
            channels: ['channel2'],
            messages: [Message(name: 'event2')],
          ),
        ]);

        expect(results.length, equals(2));
        expect(results[0].channel, equals('channel1'));
        expect(results[1].channel, equals('channel2'));
      });

      test('RSC22c5 - Multiple channels in spec produces multiple results',
          () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(201, [
              {'channel': 'channel1', 'messageId': 'msg1'},
              {'channel': 'channel2', 'messageId': 'msg1'},
              {'channel': 'channel3', 'messageId': 'msg1'},
            ]);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final results = await client.batchPublish(
          BatchPublishSpec(
            channels: ['channel1', 'channel2', 'channel3'],
            messages: [Message(name: 'event')],
          ),
        );

        expect(results.length, equals(3));
      });

      test('RSC22c6 - Messages are encoded according to RSL4', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(201, [
              {'channel': 'channel1', 'messageId': 'msg1'},
            ]);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.batchPublish(
          BatchPublishSpec(
            channels: ['channel1'],
            messages: [
              Message(
                name: 'event',
                data: {'key': 'value'},
                clientId: 'client1',
              ),
            ],
          ),
        );

        final request = capturedRequests[0];
        final body = json.decode(request.body!) as Map;
        final messages = body['messages'] as List;

        expect(messages[0]['name'], equals('event'));
        expect(messages[0]['data'], equals('{"key":"value"}'));
        expect(messages[0]['clientId'], equals('client1'));
      });

      test('RSC22c7 - Request uses correct authentication', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(201, [
              {'channel': 'channel1', 'messageId': 'msg1'},
            ]);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.batchPublish(
          BatchPublishSpec(
            channels: ['channel1'],
            messages: [Message(name: 'event')],
          ),
        );

        final request = capturedRequests[0];
        expect(request.headers['Authorization'], startsWith('Basic '));
      });
    });

    group('RSC22d - Idempotent publishing', () {
      test('RSC22d1 - Idempotent IDs generated when enabled', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(201, [
              {'channel': 'channel1', 'messageId': 'msg1'},
            ]);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions(
            key: 'appId.keyId:keySecret',
            idempotentRestPublishing: true,
          ),
          httpClient: mockHttp,
        );

        await client.batchPublish(
          BatchPublishSpec(
            channels: ['channel1'],
            messages: [Message(name: 'event1'), Message(name: 'event2')],
          ),
        );

        final request = capturedRequests[0];
        final body = json.decode(request.body!) as Map;
        final messages = body['messages'] as List;

        // Both messages should have IDs
        expect(messages[0]['id'], isNotNull);
        expect(messages[1]['id'], isNotNull);

        // IDs should be different
        expect(messages[0]['id'], isNot(equals(messages[1]['id'])));
      });

      test('RSC22d3 - Explicit message IDs preserved', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(201, [
              {'channel': 'channel1', 'messageId': 'my-custom-id'},
            ]);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions(
            key: 'appId.keyId:keySecret',
            idempotentRestPublishing: true,
          ),
          httpClient: mockHttp,
        );

        await client.batchPublish(
          BatchPublishSpec(
            channels: ['channel1'],
            messages: [Message(id: 'my-custom-id', name: 'event')],
          ),
        );

        final request = capturedRequests[0];
        final body = json.decode(request.body!) as Map;
        final messages = body['messages'] as List;

        expect(messages[0]['id'], equals('my-custom-id'));
      });

      test('RSC22d4 - Idempotent IDs not generated when disabled', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(201, [
              {'channel': 'channel1', 'messageId': 'msg1'},
            ]);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions(
            key: 'appId.keyId:keySecret',
            idempotentRestPublishing: false,
          ),
          httpClient: mockHttp,
        );

        await client.batchPublish(
          BatchPublishSpec(
            channels: ['channel1'],
            messages: [Message(name: 'event')],
          ),
        );

        final request = capturedRequests[0];
        final body = json.decode(request.body!) as Map;
        final messages = body['messages'] as List;

        // Message should not have auto-generated ID
        expect(messages[0]['id'], isNull);
      });
    });

    group('BSP2 - BatchPublishSpec', () {
      test('BSP2a - channels is array of strings', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(201, [
              {'channel': 'ch1', 'messageId': 'msg1'},
              {'channel': 'ch2', 'messageId': 'msg1'},
            ]);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.batchPublish(
          BatchPublishSpec(
            channels: ['ch1', 'ch2'],
            messages: [Message(name: 'event')],
          ),
        );

        final request = capturedRequests[0];
        final body = json.decode(request.body!) as Map;

        expect(body['channels'], isList);
        expect(body['channels'], equals(['ch1', 'ch2']));
      });

      test('BSP2b - messages is array of Message objects', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(201, [
              {'channel': 'channel1', 'messageId': 'msg1'},
            ]);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.batchPublish(
          BatchPublishSpec(
            channels: ['channel1'],
            messages: [
              Message(name: 'event1', data: 'data1'),
              Message(name: 'event2', data: 'data2'),
            ],
          ),
        );

        final request = capturedRequests[0];
        final body = json.decode(request.body!) as Map;

        expect(body['messages'], isList);
        expect((body['messages'] as List).length, equals(2));
      });
    });

    group('BPR2 - BatchPublishSuccessResult', () {
      test('BPR2a - channel field contains channel name', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(201, [
              {'channel': 'my-channel', 'messageId': 'msg1'},
            ]);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final results = await client.batchPublish(
          BatchPublishSpec(
            channels: ['my-channel'],
            messages: [Message(name: 'event')],
          ),
        );

        expect(results[0].channel, equals('my-channel'));
      });

      test('BPR2b - messageId contains the message ID prefix', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(201, [
              {'channel': 'channel1', 'messageId': 'abc123'},
            ]);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final results = await client.batchPublish(
          BatchPublishSpec(
            channels: ['channel1'],
            messages: [Message(name: 'event')],
          ),
        );

        expect(results[0], isA<BatchPublishSuccessResult>());
        expect((results[0] as BatchPublishSuccessResult).messageId,
            equals('abc123'));
      });

      test('BPR2c - serials contains array of message serials', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(201, [
              {
                'channel': 'channel1',
                'messageId': 'msg1',
                'serials': ['serial1', 'serial2'],
              },
            ]);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final results = await client.batchPublish(
          BatchPublishSpec(
            channels: ['channel1'],
            messages: [Message(name: 'e1'), Message(name: 'e2')],
          ),
        );

        final successResult = results[0] as BatchPublishSuccessResult;
        expect(successResult.serials, equals(['serial1', 'serial2']));
      });

      test('BPR2c1 - serials may contain null for conflated messages',
          () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(201, [
              {
                'channel': 'channel1',
                'messageId': 'msg1',
                'serials': ['serial1', null, 'serial3'],
              },
            ]);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final results = await client.batchPublish(
          BatchPublishSpec(
            channels: ['channel1'],
            messages: [
              Message(name: 'e1'),
              Message(name: 'e2'),
              Message(name: 'e3'),
            ],
          ),
        );

        final successResult = results[0] as BatchPublishSuccessResult;
        expect(successResult.serials, equals(['serial1', null, 'serial3']));
      });
    });

    group('BPF2 - BatchPublishFailureResult', () {
      test('BPF2a - channel field contains failed channel name', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(207, [
              {'channel': 'ok-channel', 'messageId': 'msg1'},
              {
                'channel': 'failed-channel',
                'error': {'code': 40300, 'message': 'Forbidden'},
              },
            ]);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final results = await client.batchPublish(
          BatchPublishSpec(
            channels: ['ok-channel', 'failed-channel'],
            messages: [Message(name: 'event')],
          ),
        );

        expect(results[1].channel, equals('failed-channel'));
      });

      test('BPF2b - error contains ErrorInfo for failure reason', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(207, [
              {
                'channel': 'channel1',
                'error': {
                  'code': 40300,
                  'statusCode': 403,
                  'message': 'Publish not permitted',
                },
              },
            ]);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final results = await client.batchPublish(
          BatchPublishSpec(
            channels: ['channel1'],
            messages: [Message(name: 'event')],
          ),
        );

        expect(results[0], isA<BatchPublishFailureResult>());
        final failureResult = results[0] as BatchPublishFailureResult;
        expect(failureResult.error.code, equals(40300));
        expect(failureResult.error.statusCode, equals(403));
        expect(failureResult.error.message, equals('Publish not permitted'));
      });
    });

    group('BatchResult - Success/failure detection', () {
      test('BatchResult1 - Partial success with mixed results', () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(207, [
              {'channel': 'channel1', 'messageId': 'msg1'},
              {
                'channel': 'channel2',
                'error': {'code': 40300, 'message': 'Forbidden'},
              },
              {'channel': 'channel3', 'messageId': 'msg3'},
            ]);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final results = await client.batchPublish(
          BatchPublishSpec(
            channels: ['channel1', 'channel2', 'channel3'],
            messages: [Message(name: 'event')],
          ),
        );

        expect(results.length, equals(3));
        expect(results[0].isSuccess, isTrue);
        expect(results[1].isSuccess, isFalse);
        expect(results[2].isSuccess, isTrue);
      });

      test('BatchResult2 - Distinguishing success from failure results',
          () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(207, [
              {'channel': 'channel1', 'messageId': 'msg1'},
              {
                'channel': 'channel2',
                'error': {'code': 40300, 'message': 'Forbidden'},
              },
            ]);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        final results = await client.batchPublish(
          BatchPublishSpec(
            channels: ['channel1', 'channel2'],
            messages: [Message(name: 'event')],
          ),
        );

        expect(results[0], isA<BatchPublishSuccessResult>());
        expect(results[1], isA<BatchPublishFailureResult>());

        // Can safely cast after type check
        final success = results[0] as BatchPublishSuccessResult;
        final failure = results[1] as BatchPublishFailureResult;

        expect(success.messageId, isNotNull);
        expect(failure.error, isNotNull);
      });
    });

    group('RSC22 - Error handling', () {
      test('RSC22_Error1 - Authentication error throws AblyException',
          () async {
        mockHttp = MockHttpClient(
          onRequest: (req) {
            req.respondWith(401, {
              'error': {'code': 40100, 'message': 'Unauthorized'},
            });
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        expect(
          () => client.batchPublish(
            BatchPublishSpec(
              channels: ['channel1'],
              messages: [Message(name: 'event')],
            ),
          ),
          throwsA(
            isA<AblyException>().having(
              (e) => e.code,
              'code',
              equals(40100),
            ),
          ),
        );
      });

      test('RSC22_Error2 - Invalid argument throws ArgumentError', () async {
        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        expect(
          () => client.batchPublish('invalid'),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('RSC22 - Request headers', () {
      test('RSC22_Headers1 - Includes standard Ably headers', () async {
        final capturedRequests = <CapturedRequest>[];

        mockHttp = MockHttpClient(
          onRequest: (req) {
            capturedRequests.add(CapturedRequest(
              method: req.method,
              url: req.url,
              headers: req.headers,
              body: req.bodyAsString,
            ));

            req.respondWith(201, [
              {'channel': 'channel1', 'messageId': 'msg1'},
            ]);
          },
        );

        final client = Rest.forTesting(
          options: ClientOptions.fromKey('appId.keyId:keySecret'),
          httpClient: mockHttp,
        );

        await client.batchPublish(
          BatchPublishSpec(
            channels: ['channel1'],
            messages: [Message(name: 'event')],
          ),
        );

        final request = capturedRequests[0];
        expect(request.headers['X-Ably-Version'], isNotNull);
        expect(request.headers['Ably-Agent'], isNotNull);
        // Content-Type depends on useBinaryProtocol setting (default is msgpack)
        expect(
          request.headers['Content-Type'],
          anyOf(equals('application/json'), equals('application/x-msgpack')),
        );
      });
    });
  });
}
