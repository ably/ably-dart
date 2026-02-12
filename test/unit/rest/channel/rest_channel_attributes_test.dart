import 'package:test/test.dart';
import 'package:ably_dart/ably_dart.dart';
import '../../../helpers/mock_http_client.dart';

/// Unit tests for REST channel attributes and methods (RSL7, RSL8, RSL9).
///
/// These tests use a mocked HTTP client to verify RestChannel attributes
/// and request formation for the status endpoint.
///
/// Spec: uts/test/rest/unit/channel/rest_channel_attributes.md
void main() {
  group('RSL9 - RestChannel name attribute', () {
    test('returns the name used when getting the channel', () {
      final client = Rest.forTesting(
        options: ClientOptions.fromKey('fake.key:secret'),
      );

      final channel = client.channels.get('my-channel');
      expect(channel.name, equals('my-channel'));

      // Also works with special characters
      final channel2 = client.channels.get('namespace:channel-name');
      expect(channel2.name, equals('namespace:channel-name'));
    });
  });

  group('RSL7 - RestChannel setOptions', () {
    test('setOptions completes without error', () async {
      final client = Rest.forTesting(
        options: ClientOptions.fromKey('fake.key:secret'),
      );

      final channel = client.channels.get('test-RSL7');
      // setOptions should complete without throwing
      await channel.setOptions(RestChannelOptions());
    });
  });

  group('RSL8 - RestChannel status', () {
    test('sends GET request to /channels/<channelId>', () async {
      final mockHttp = MockHttpClient(
        onRequest: (request) {
          request.respondWith(200, {
            'channelId': 'test-RSL8',
            'status': {
              'isActive': true,
              'occupancy': {
                'metrics': {
                  'connections': 0,
                  'publishers': 0,
                  'subscribers': 0,
                  'presenceConnections': 0,
                  'presenceMembers': 0,
                  'presenceSubscribers': 0,
                },
              },
            },
          });
        },
      );

      final client = Rest.forTesting(
        options: ClientOptions.fromKey('fake.key:secret'),
        httpClient: mockHttp,
      );

      final channel = client.channels.get('test-RSL8');
      await channel.status();

      expect(mockHttp.capturedRequests.length, equals(1));
      expect(mockHttp.capturedRequests[0].method, equals('GET'));
      expect(
        mockHttp.capturedRequests[0].url.path,
        equals('/channels/test-RSL8'),
      );

      mockHttp.dispose();
    });

    test('URL-encodes special characters in channel name', () async {
      final mockHttp = MockHttpClient(
        onRequest: (request) {
          request.respondWith(200, {
            'channelId': 'namespace:my channel',
            'status': {
              'isActive': true,
              'occupancy': {
                'metrics': {
                  'connections': 0,
                  'publishers': 0,
                  'subscribers': 0,
                  'presenceConnections': 0,
                  'presenceMembers': 0,
                  'presenceSubscribers': 0,
                },
              },
            },
          });
        },
      );

      final client = Rest.forTesting(
        options: ClientOptions.fromKey('fake.key:secret'),
        httpClient: mockHttp,
      );

      final channel = client.channels.get('namespace:my channel');
      await channel.status();

      expect(mockHttp.capturedRequests.length, equals(1));
      expect(mockHttp.capturedRequests[0].method, equals('GET'));
      expect(
        mockHttp.capturedRequests[0].url.path,
        equals(
          '/channels/${Uri.encodeComponent('namespace:my channel')}',
        ),
      );

      mockHttp.dispose();
    });
  });

  group('RSL8a - status returns ChannelDetails', () {
    test('parses response into ChannelDetails with correct attributes',
        () async {
      final mockHttp = MockHttpClient(
        onRequest: (request) {
          request.respondWith(200, {
            'channelId': 'test-RSL8a',
            'status': {
              'isActive': true,
              'occupancy': {
                'metrics': {
                  'connections': 5,
                  'publishers': 2,
                  'subscribers': 3,
                  'presenceConnections': 1,
                  'presenceMembers': 1,
                  'presenceSubscribers': 0,
                },
              },
            },
          });
        },
      );

      final client = Rest.forTesting(
        options: ClientOptions.fromKey('fake.key:secret'),
        httpClient: mockHttp,
      );

      final channel = client.channels.get('test-RSL8a');
      final result = await channel.status();

      // CHD2a: channelId attribute
      expect(result.channelId, equals('test-RSL8a'));

      // CHD2b: status attribute
      expect(result.status, isNotNull);
      expect(result.status!.isActive, isTrue);

      // CHS2b: occupancy metrics
      expect(result.status!.occupancy, isNotNull);
      expect(result.status!.occupancy!.metrics, isNotNull);
      expect(result.status!.occupancy!.metrics!.connections, equals(5));
      expect(result.status!.occupancy!.metrics!.publishers, equals(2));
      expect(result.status!.occupancy!.metrics!.subscribers, equals(3));

      mockHttp.dispose();
    });
  });
}
