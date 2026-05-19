import 'package:flutter/foundation.dart';

class Constants {
  static const String ablyApiKey = 'ABLY_API_KEY';
  static String platform = defaultTargetPlatform.name;
  static String clientId = 'ably-dart-example-app-$platform-client-id';
  static String sandboxEndpoint = 'nonprod:sandbox';
  static const String channelName = 'test-channel';
  static const encryptedChannelName = 'encrypted-test-channel';
  static const String channelNameForPushNotifications =
      'push:test-push-channel';
  static const String pushMetaChannelName = '[meta]log:push';
  static const examplePasswordForEncryptedChannel =
      'password-to-encrypt-and-decrypt-text';
}
