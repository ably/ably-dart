@Tags(['integration'])
library;

import 'package:test/test.dart';
import 'package:ably_dart/ably_dart.dart';

import '../../helpers/test_app_helper.dart';

void main() {
  late TestApp testApp;

  setUpAll(() async {
    testApp = await TestApp.provision();
  });

  tearDownAll(() async {
    await testApp.delete();
  });

  // Helper: build a key-authenticated REST client using key[1] which has
  // push-admin and push-subscribe capabilities on pushenabled:* channels.
  Rest buildAdminClient() => Rest(
        options: ClientOptions(
          key: testApp.keys[1].keyStr,
          endpoint: 'nonprod:sandbox',
          useBinaryProtocol: false,
        ),
      );

  // Helper: generate a unique device ID for each test.
  String uniqueDeviceId(String tag) =>
      'test-device-$tag-${DateTime.now().millisecondsSinceEpoch}';

  // Helper: create a minimal DeviceDetails for registration.
  DeviceDetails makeDeviceDetails(String deviceId) {
    return DeviceDetails(
      id: deviceId,
      platform: 'ios',
      formFactor: 'phone',
      push: DevicePushDetails(
        recipient: {
          'transportType': 'apns',
          'deviceToken': 'fake-apns-token-$deviceId',
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RSH7a+RSH7c — subscribeDevice / unsubscribeDevice
  // ---------------------------------------------------------------------------
  group('RSH7a+RSH7c - subscribeDevice / unsubscribeDevice', () {
    test(
        'RSH7a+RSH7c - register device, subscribe via channel.push.subscribeDevice, '
        'verify via admin list, unsubscribe, verify removed', () async {
      final adminClient = buildAdminClient();
      addTearDown(adminClient.close);

      final deviceId = uniqueDeviceId('rsh7a');
      final channelName =
          'pushenabled:rsh7a-${DateTime.now().millisecondsSinceEpoch}';

      // Register device via admin API
      await adminClient.push.admin.deviceRegistrations
          .save(makeDeviceDetails(deviceId));

      // Build a separate client that simulates the local device
      final deviceClient = Rest(
        options: ClientOptions(
          key: testApp.keys[1].keyStr,
          endpoint: 'nonprod:sandbox',
          useBinaryProtocol: false,
        ),
      );
      addTearDown(deviceClient.close);
      addTearDown(() async {
        await adminClient.push.admin.deviceRegistrations.remove(deviceId);
      });

      // Set the local device on the client
      deviceClient.device = LocalDevice(
        id: deviceId,
        deviceIdentityToken: 'fake-identity-token-$deviceId',
        platform: 'ios',
        formFactor: 'phone',
        push: DevicePushDetails(
          recipient: {
            'transportType': 'apns',
            'deviceToken': 'fake-apns-token-$deviceId',
          },
        ),
      );

      final channel = deviceClient.channels.get(channelName);

      // RSH7a: Subscribe device
      await channel.push.subscribeDevice();

      // Verify via admin list
      final subs = await adminClient.push.admin.channelSubscriptions
          .list({'channel': channelName, 'deviceId': deviceId});
      expect(subs.items, isNotEmpty);
      expect(
        subs.items.any((s) => s.deviceId == deviceId),
        isTrue,
      );

      // RSH7c: Unsubscribe device
      await channel.push.unsubscribeDevice();

      // Verify removed
      final subsAfter = await adminClient.push.admin.channelSubscriptions
          .list({'channel': channelName, 'deviceId': deviceId});
      expect(subsAfter.items, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // RSH7b+RSH7d — subscribeClient / unsubscribeClient
  // ---------------------------------------------------------------------------
  group('RSH7b+RSH7d - subscribeClient / unsubscribeClient', () {
    test(
        'RSH7b+RSH7d - set device with clientId, subscribe via channel.push.subscribeClient, '
        'verify via admin list, unsubscribe, verify removed', () async {
      final adminClient = buildAdminClient();
      addTearDown(adminClient.close);

      final deviceId = uniqueDeviceId('rsh7b');
      final clientId =
          'push-client-rsh7b-${DateTime.now().millisecondsSinceEpoch}';
      final channelName =
          'pushenabled:rsh7b-${DateTime.now().millisecondsSinceEpoch}';

      // Build a client that simulates the local device with a clientId
      final deviceClient = Rest(
        options: ClientOptions(
          key: testApp.keys[1].keyStr,
          endpoint: 'nonprod:sandbox',
          useBinaryProtocol: false,
        ),
      );
      addTearDown(deviceClient.close);

      // Set the local device on the client, including a clientId
      deviceClient.device = LocalDevice(
        id: deviceId,
        clientId: clientId,
        deviceIdentityToken: 'fake-identity-token-$deviceId',
        platform: 'ios',
        formFactor: 'phone',
        push: DevicePushDetails(
          recipient: {
            'transportType': 'apns',
            'deviceToken': 'fake-apns-token-$deviceId',
          },
        ),
      );

      final channel = deviceClient.channels.get(channelName);

      // RSH7b: Subscribe client
      await channel.push.subscribeClient();

      // Verify via admin list using clientId
      final subs = await adminClient.push.admin.channelSubscriptions
          .list({'channel': channelName, 'clientId': clientId});
      expect(subs.items, isNotEmpty);
      expect(
        subs.items.any((s) => s.clientId == clientId),
        isTrue,
      );

      // RSH7d: Unsubscribe client
      await channel.push.unsubscribeClient();

      // Verify removed
      final subsAfter = await adminClient.push.admin.channelSubscriptions
          .list({'channel': channelName, 'clientId': clientId});
      expect(subsAfter.items, isEmpty);
    });
  });
}
