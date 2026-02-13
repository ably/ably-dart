import 'dart:math';

import 'package:test/test.dart';
import 'package:ably_dart/ably_dart.dart';

import '../../helpers/test_app_helper.dart';

/// Integration tests for Push Admin (RSH1a, RSH1b1–RSH1b5, RSH1c1–RSH1c5).
///
/// Runs against the Ably Sandbox environment.
///
/// Spec: uts/test/rest/integration/push_admin.md
void main() {
  late TestApp testApp;
  late String apiKey;

  final random = Random();
  String randomId() =>
      '${DateTime.now().millisecondsSinceEpoch}-${random.nextInt(999999)}';

  setUpAll(() async {
    testApp = await TestApp.provision();
    apiKey = testApp.keys[0].keyStr;
    print('Provisioned test app: ${testApp.appId}');
  });

  tearDownAll(() async {
    await testApp.delete();
    print('Deleted test app: ${testApp.appId}');
  });

  Rest createClient() => Rest(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

  group('RSH1a - publish', () {
    test('sends push notification to clientId recipient', () async {
      final client = createClient();

      // Should not throw — sandbox accepts publish even with no real device
      await client.push.admin.publish(
        {'clientId': 'test-client-push'},
        {
          'notification': {
            'title': 'Integration Test',
            'body': 'Hello from push admin',
          },
        },
      );

      await client.close();
    });

    test('rejects invalid recipient', () async {
      final client = createClient();

      expect(
        () => client.push.admin.publish(
          {},
          {
            'notification': {'title': 'Test'},
          },
        ),
        throwsA(isA<AblyException>()),
      );

      await client.close();
    });
  });

  group('RSH1b3, RSH1b1 - save and get device registration', () {
    test('saves and retrieves a device', () async {
      final client = createClient();
      final deviceId = 'test-device-${randomId()}';

      try {
        final saved = await client.push.admin.deviceRegistrations.save(
          DeviceDetails(
            id: deviceId,
            platform: 'ios',
            formFactor: 'phone',
            push: DevicePushDetails(
              recipient: {
                'transportType': 'apns',
                'deviceToken': 'test-token-${randomId()}',
              },
            ),
          ),
        );

        expect(saved, isA<DeviceDetails>());
        expect(saved.id, equals(deviceId));
        expect(saved.platform, equals('ios'));
        expect(saved.formFactor, equals('phone'));
        expect(saved.push!.recipient['transportType'], equals('apns'));

        // Retrieve the same device
        final retrieved =
            await client.push.admin.deviceRegistrations.get(deviceId);
        expect(retrieved, isA<DeviceDetails>());
        expect(retrieved.id, equals(deviceId));
        expect(retrieved.platform, equals('ios'));
      } finally {
        await client.push.admin.deviceRegistrations.remove(deviceId);
        await client.close();
      }
    });
  });

  group('RSH1b3 - save updates existing device registration', () {
    test('updates device with same ID', () async {
      final client = createClient();
      final deviceId = 'test-device-update-${randomId()}';

      try {
        // Initial save
        await client.push.admin.deviceRegistrations.save(
          DeviceDetails(
            id: deviceId,
            platform: 'ios',
            formFactor: 'phone',
            push: DevicePushDetails(
              recipient: {
                'transportType': 'apns',
                'deviceToken': 'token-v1',
              },
            ),
          ),
        );

        // Update with new token
        final updated = await client.push.admin.deviceRegistrations.save(
          DeviceDetails(
            id: deviceId,
            platform: 'ios',
            formFactor: 'phone',
            push: DevicePushDetails(
              recipient: {
                'transportType': 'apns',
                'deviceToken': 'token-v2',
              },
            ),
          ),
        );

        expect(updated.id, equals(deviceId));
        expect(updated.push!.recipient['deviceToken'], equals('token-v2'));

        // Verify via get
        final retrieved =
            await client.push.admin.deviceRegistrations.get(deviceId);
        expect(retrieved.push!.recipient['deviceToken'], equals('token-v2'));
      } finally {
        await client.push.admin.deviceRegistrations.remove(deviceId);
        await client.close();
      }
    });
  });

  group('RSH1b1 - get returns error for unknown device', () {
    test('returns 404 for nonexistent device', () async {
      final client = createClient();

      try {
        await client.push.admin.deviceRegistrations
            .get('nonexistent-device-${randomId()}');
        fail('Expected AblyException');
      } on AblyException catch (e) {
        expect(e.errorInfo?.statusCode, equals(404));
      } finally {
        await client.close();
      }
    });
  });

  group('RSH1b2 - list device registrations', () {
    test('lists devices filtered by deviceId', () async {
      final client = createClient();
      final deviceId = 'test-device-list-${randomId()}';

      try {
        await client.push.admin.deviceRegistrations.save(
          DeviceDetails(
            id: deviceId,
            platform: 'android',
            formFactor: 'tablet',
            push: DevicePushDetails(
              recipient: {
                'transportType': 'gcm',
                'registrationToken': 'test-token',
              },
            ),
          ),
        );

        final result = await client.push.admin.deviceRegistrations
            .list({'deviceId': deviceId});

        expect(result, isA<PaginatedResult<DeviceDetails>>());
        expect(result.items.length, equals(1));
        expect(result.items[0].id, equals(deviceId));
        expect(result.items[0].platform, equals('android'));
      } finally {
        await client.push.admin.deviceRegistrations.remove(deviceId);
        await client.close();
      }
    });

    test('supports pagination with limit', () async {
      final client = createClient();
      final clientId = 'test-client-list-${randomId()}';
      final deviceIds = <String>[];

      try {
        // Register 3 devices with the same clientId
        for (var i = 1; i <= 3; i++) {
          final deviceId = 'test-device-limit-$i-${randomId()}';
          deviceIds.add(deviceId);
          await client.push.admin.deviceRegistrations.save(
            DeviceDetails(
              id: deviceId,
              clientId: clientId,
              platform: 'ios',
              formFactor: 'phone',
              push: DevicePushDetails(
                recipient: {
                  'transportType': 'apns',
                  'deviceToken': 'token-$i',
                },
              ),
            ),
          );
        }

        final result = await client.push.admin.deviceRegistrations.list({
          'clientId': clientId,
          'limit': '2',
        });

        expect(result.items.length, lessThanOrEqualTo(2));
        expect(result.hasNext(), isTrue);
      } finally {
        for (final deviceId in deviceIds) {
          await client.push.admin.deviceRegistrations.remove(deviceId);
        }
        await client.close();
      }
    });
  });

  group('RSH1b4 - remove device registration', () {
    test('removes registered device', () async {
      final client = createClient();
      final deviceId = 'test-device-remove-${randomId()}';

      // Register a device
      await client.push.admin.deviceRegistrations.save(
        DeviceDetails(
          id: deviceId,
          platform: 'ios',
          formFactor: 'phone',
          push: DevicePushDetails(
            recipient: {
              'transportType': 'apns',
              'deviceToken': 'test-token',
            },
          ),
        ),
      );

      // Remove it
      await client.push.admin.deviceRegistrations.remove(deviceId);

      // Verify it's gone
      try {
        await client.push.admin.deviceRegistrations.get(deviceId);
        fail('Expected AblyException');
      } on AblyException catch (e) {
        expect(e.errorInfo?.statusCode, equals(404));
      }

      await client.close();
    });

    test('succeeds for nonexistent device', () async {
      final client = createClient();

      // Should not throw
      await client.push.admin.deviceRegistrations
          .remove('nonexistent-device-${randomId()}');

      await client.close();
    });
  });

  group('RSH1b5 - removeWhere deletes devices by clientId', () {
    test('bulk removes devices by clientId', () async {
      final client = createClient();
      final clientId = 'test-client-removeWhere-${randomId()}';
      final deviceIds = <String>[];

      // Register two devices with the same clientId
      for (var i = 1; i <= 2; i++) {
        final deviceId = 'test-device-rw-$i-${randomId()}';
        deviceIds.add(deviceId);
        await client.push.admin.deviceRegistrations.save(
          DeviceDetails(
            id: deviceId,
            clientId: clientId,
            platform: 'ios',
            formFactor: 'phone',
            push: DevicePushDetails(
              recipient: {
                'transportType': 'apns',
                'deviceToken': 'token-$i',
              },
            ),
          ),
        );
      }

      // Remove all devices for this clientId
      await client.push.admin.deviceRegistrations
          .removeWhere({'clientId': clientId});

      // Verify both are gone
      final result = await client.push.admin.deviceRegistrations
          .list({'clientId': clientId});
      expect(result.items.length, equals(0));

      await client.close();
    });
  });

  group('RSH1c3, RSH1c1 - save and list channel subscriptions', () {
    test('saves and lists device subscription', () async {
      final client = createClient();
      final deviceId = 'test-device-sub-${randomId()}';
      final channelName = 'pushenabled:test-sub-${randomId()}';

      try {
        // Register a device first (required for deviceId subscriptions)
        await client.push.admin.deviceRegistrations.save(
          DeviceDetails(
            id: deviceId,
            platform: 'ios',
            formFactor: 'phone',
            push: DevicePushDetails(
              recipient: {
                'transportType': 'apns',
                'deviceToken': 'test-token',
              },
            ),
          ),
        );

        // Save a channel subscription
        final saved = await client.push.admin.channelSubscriptions.save(
          PushChannelSubscription.forDevice(
            channel: channelName,
            deviceId: deviceId,
          ),
        );

        expect(saved, isA<PushChannelSubscription>());
        expect(saved.channel, equals(channelName));
        expect(saved.deviceId, equals(deviceId));

        // List subscriptions for this channel
        final result = await client.push.admin.channelSubscriptions
            .list({'channel': channelName});
        expect(result, isA<PaginatedResult<PushChannelSubscription>>());
        expect(result.items.length, greaterThanOrEqualTo(1));

        final found = result.items.any((sub) => sub.deviceId == deviceId);
        expect(found, isTrue);
      } finally {
        await client.push.admin.channelSubscriptions.remove(
          PushChannelSubscription.forDevice(
            channel: channelName,
            deviceId: deviceId,
          ),
        );
        await client.push.admin.deviceRegistrations.remove(deviceId);
        await client.close();
      }
    });
  });

  group('RSH1c3 - save channel subscription with clientId', () {
    test('saves clientId-based subscription', () async {
      final client = createClient();
      final clientId = 'test-client-sub-${randomId()}';
      final channelName = 'pushenabled:test-clientsub-${randomId()}';

      try {
        final saved = await client.push.admin.channelSubscriptions.save(
          PushChannelSubscription.forClientId(
            channel: channelName,
            clientId: clientId,
          ),
        );

        expect(saved.channel, equals(channelName));
        expect(saved.clientId, equals(clientId));
      } finally {
        await client.push.admin.channelSubscriptions.remove(
          PushChannelSubscription.forClientId(
            channel: channelName,
            clientId: clientId,
          ),
        );
        await client.close();
      }
    });
  });

  group('RSH1c2 - listChannels', () {
    test('returns channel names with subscriptions', () async {
      final client = createClient();
      final clientId = 'test-client-lc-${randomId()}';
      final channelName = 'pushenabled:test-listchannels-${randomId()}';

      try {
        // Create a subscription to ensure the channel appears
        await client.push.admin.channelSubscriptions.save(
          PushChannelSubscription.forClientId(
            channel: channelName,
            clientId: clientId,
          ),
        );

        final result =
            await client.push.admin.channelSubscriptions.listChannels({});

        expect(result, isA<PaginatedResult<String>>());
        expect(result.items, contains(channelName));
      } finally {
        await client.push.admin.channelSubscriptions.remove(
          PushChannelSubscription.forClientId(
            channel: channelName,
            clientId: clientId,
          ),
        );
        await client.close();
      }
    });
  });

  group('RSH1c4 - remove channel subscription', () {
    test('removes subscription and no longer in list', () async {
      final client = createClient();
      final clientId = 'test-client-rm-${randomId()}';
      final channelName = 'pushenabled:test-remove-${randomId()}';

      // Create a subscription
      await client.push.admin.channelSubscriptions.save(
        PushChannelSubscription.forClientId(
          channel: channelName,
          clientId: clientId,
        ),
      );

      // Remove the subscription
      await client.push.admin.channelSubscriptions.remove(
        PushChannelSubscription.forClientId(
          channel: channelName,
          clientId: clientId,
        ),
      );

      // Verify it's gone
      final result = await client.push.admin.channelSubscriptions.list({
        'channel': channelName,
        'clientId': clientId,
      });
      expect(result.items.length, equals(0));

      await client.close();
    });

    test('succeeds for nonexistent subscription', () async {
      final client = createClient();

      // Should not throw
      await client.push.admin.channelSubscriptions.remove(
        PushChannelSubscription.forClientId(
          channel: 'pushenabled:nonexistent-${randomId()}',
          clientId: 'nonexistent-client',
        ),
      );

      await client.close();
    });
  });

  group('RSH1c5 - removeWhere deletes subscriptions by clientId', () {
    test('bulk removes subscriptions by clientId', () async {
      final client = createClient();
      final clientId = 'test-client-rwsub-${randomId()}';
      final channelNames = <String>[];

      // Create subscriptions on two channels for the same clientId
      for (var i = 1; i <= 2; i++) {
        final ch = 'pushenabled:test-rwsub-$i-${randomId()}';
        channelNames.add(ch);
        await client.push.admin.channelSubscriptions.save(
          PushChannelSubscription.forClientId(
            channel: ch,
            clientId: clientId,
          ),
        );
      }

      // Remove all subscriptions for this clientId
      await client.push.admin.channelSubscriptions
          .removeWhere({'clientId': clientId});

      // Verify they're all gone
      final result = await client.push.admin.channelSubscriptions
          .list({'clientId': clientId});
      expect(result.items.length, equals(0));

      await client.close();
    });
  });
}
