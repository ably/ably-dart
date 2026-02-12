import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:ably_dart/ably_dart.dart';
import 'package:test/test.dart';

import '../../helpers/test_app_helper.dart';
import '../../helpers/vcdiff_adapter.dart';

/// Integration tests for vcdiff delta decoding against the Ably sandbox.
///
/// Spec: PC3, PC3a, RTL18, RTL18b, RTL18c, RTL19b, RTL20
///
/// UTS spec: uts/test/realtime/integration/delta_decoding_test.md
void main() {
  late TestApp testApp;
  late String apiKey;

  /// Test data — intentionally similar between messages so the server
  /// generates small vcdiff deltas.
  final testData = [
    {'foo': 'bar', 'count': 1, 'status': 'active'},
    {'foo': 'bar', 'count': 2, 'status': 'active'},
    {'foo': 'bar', 'count': 2, 'status': 'inactive'},
    {'foo': 'bar', 'count': 3, 'status': 'inactive'},
    {'foo': 'bar', 'count': 3, 'status': 'active'},
  ];

  setUpAll(() async {
    testApp = await TestApp.provision();
    apiKey = testApp.keys[0].keyStr;
    print('Provisioned test app: ${testApp.appId}');
  });

  tearDownAll(() async {
    await testApp.delete();
    print('Deleted test app: ${testApp.appId}');
  });

  group('PC3 - Delta plugin decodes messages end-to-end', () {
    test('all published messages received with correct data via delta decoding',
        () async {
      final channelName = 'delta-PC3-${_randomId()}';
      final decoder = VCDiffDecoderAdapter();

      final client = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
          autoConnect: false,
          plugins: {'vcdiff': decoder},
        ),
      );

      client.connect();
      await _awaitState(
        client.connection,
        ConnectionState.connected,
      );

      final channel = client.channels.get(
        channelName,
        const RealtimeChannelOptions(params: {'delta': 'vcdiff'}),
      );

      await channel.attach();

      final receivedMessages = <Message>[];

      // Fail if channel reattaches (decode failure)
      channel.on(ChannelEvent.attaching).listen((change) {
        fail('Channel reattaching: ${change.reason}');
      });

      channel.subscribe(receivedMessages.add);

      // Publish all messages sequentially
      for (var i = 0; i < testData.length; i++) {
        await channel.publish(name: '$i', data: testData[i]);
      }

      // Wait for all messages
      await _waitUntil(
        () => receivedMessages.length >= testData.length,
        timeout: const Duration(seconds: 15),
      );

      // Verify all messages received correctly
      for (var i = 0; i < testData.length; i++) {
        expect(receivedMessages[i].name, equals('$i'));
        expect(receivedMessages[i].data, equals(testData[i]));
      }

      // First message is full payload, rest are deltas
      expect(decoder.decodeCount, equals(testData.length - 1));

      client.close();
    });
  });

  group('RTL19b - Dissimilar payloads without delta encoding', () {
    test('random binary payloads received correctly', () async {
      final channelName = 'delta-dissimilar-${_randomId()}';
      const messageCount = 5;
      final decoder = VCDiffDecoderAdapter();

      final client = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
          autoConnect: false,
          plugins: {'vcdiff': decoder},
        ),
      );

      // Generate random 1KB binary payloads
      final random = Random();
      final payloads = List.generate(
        messageCount,
        (_) => Uint8List.fromList(
          List.generate(1024, (_) => random.nextInt(256)),
        ),
      );

      client.connect();
      await _awaitState(
        client.connection,
        ConnectionState.connected,
      );

      final channel = client.channels.get(
        channelName,
        const RealtimeChannelOptions(params: {'delta': 'vcdiff'}),
      );

      await channel.attach();

      final receivedMessages = <Message>[];

      channel.on(ChannelEvent.attaching).listen((change) {
        fail('Channel reattaching: ${change.reason}');
      });

      channel.subscribe(receivedMessages.add);

      for (var i = 0; i < messageCount; i++) {
        await channel.publish(name: '$i', data: payloads[i]);
      }

      await _waitUntil(
        () => receivedMessages.length >= messageCount,
        timeout: const Duration(seconds: 15),
      );

      for (var i = 0; i < messageCount; i++) {
        expect(receivedMessages[i].name, equals('$i'));
        expect(receivedMessages[i].data, equals(payloads[i]));
      }

      // Log decode count — server is expected to skip deltas for dissimilar
      // binary data, but we don't assert on it.
      print('Decoder called ${decoder.decodeCount} times for '
          '$messageCount dissimilar messages');

      client.close();
    });
  });

  group('PC3 - No deltas without delta channel param', () {
    test('decoder not called when channel has no delta param', () async {
      final channelName = 'delta-no-param-${_randomId()}';
      final decoder = VCDiffDecoderAdapter();

      final client = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
          autoConnect: false,
          plugins: {'vcdiff': decoder},
        ),
      );

      client.connect();
      await _awaitState(
        client.connection,
        ConnectionState.connected,
      );

      // Attach WITHOUT delta params
      final channel = client.channels.get(channelName);

      await channel.attach();

      final receivedMessages = <Message>[];
      channel.subscribe(receivedMessages.add);

      for (var i = 0; i < testData.length; i++) {
        await channel.publish(name: '$i', data: testData[i]);
      }

      await _waitUntil(
        () => receivedMessages.length >= testData.length,
        timeout: const Duration(seconds: 15),
      );

      for (var i = 0; i < testData.length; i++) {
        expect(receivedMessages[i].name, equals('$i'));
        expect(receivedMessages[i].data, equals(testData[i]));
      }

      // No deltas — decoder was never called
      expect(decoder.decodeCount, equals(0));

      client.close();
    });
  });

  group('RTL18, RTL20 - Recovery after last message ID mismatch', () {
    test('clearing last message ID triggers recovery and messages arrive',
        () async {
      final channelName = 'delta-recovery-mismatch-${_randomId()}';
      final decoder = VCDiffDecoderAdapter();

      final client = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
          autoConnect: false,
          plugins: {'vcdiff': decoder},
        ),
      );

      client.connect();
      await _awaitState(
        client.connection,
        ConnectionState.connected,
      );

      final channel = client.channels.get(
        channelName,
        const RealtimeChannelOptions(params: {'delta': 'vcdiff'}),
      );

      await channel.attach();

      final receivedMessages = <Message>[];
      final attachingReasons = <ErrorInfo?>[];

      channel.on(ChannelEvent.attaching).listen((change) {
        attachingReasons.add(change.reason);
      });

      channel.subscribe(receivedMessages.add);

      // Publish first batch of messages and wait for them to arrive
      for (var i = 0; i < 3; i++) {
        await channel.publish(name: '$i', data: testData[i]);
      }

      await _waitUntil(
        () => receivedMessages.length >= 3,
        timeout: const Duration(seconds: 15),
      );

      // Simulate message gap by clearing stored message ID
      channel.clearLastPayloadMessageId();

      // Publish more messages — the server should send deltas for these,
      // which will fail the RTL20 check and trigger recovery
      for (var i = 3; i < testData.length; i++) {
        await channel.publish(name: '$i', data: testData[i]);
      }

      // Wait for recovery and all messages to arrive
      await _waitUntil(
        () {
          // Check we have all message names (may have duplicates from resend)
          final names = receivedMessages.map((m) => m.name).toSet();
          return testData.asMap().keys.every((i) => names.contains('$i'));
        },
        timeout: const Duration(seconds: 30),
      );

      // All messages received with correct data (may have duplicates)
      for (var i = 0; i < testData.length; i++) {
        final msg = receivedMessages.where((m) => m.name == '$i').first;
        expect(msg.data, equals(testData[i]));
      }

      // RTL18c: Recovery was triggered with error code 40018
      expect(attachingReasons, isNotEmpty);
      expect(attachingReasons[0]?.code, equals(40018));

      client.close();
    });
  });

  group('RTL18 - Recovery after decode failure', () {
    test('failing decoder triggers recovery and messages arrive', () async {
      final channelName = 'delta-recovery-decode-${_randomId()}';

      // Decoder that always fails
      final failingDecoder = FailingVCDiffDecoderAdapter();

      final client = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
          autoConnect: false,
          plugins: {'vcdiff': failingDecoder},
        ),
      );

      client.connect();
      await _awaitState(
        client.connection,
        ConnectionState.connected,
      );

      final channel = client.channels.get(
        channelName,
        const RealtimeChannelOptions(params: {'delta': 'vcdiff'}),
      );

      await channel.attach();

      final receivedMessages = <Message>[];
      final attachingReasons = <ErrorInfo?>[];

      channel.on(ChannelEvent.attaching).listen((change) {
        attachingReasons.add(change.reason);
      });

      channel.subscribe(receivedMessages.add);

      for (var i = 0; i < testData.length; i++) {
        await channel.publish(name: '$i', data: testData[i]);
      }

      // Wait for all messages — first arrives as non-delta, second triggers
      // decode failure and recovery, then remaining arrive after reattach
      await _waitUntil(
        () {
          final names = receivedMessages.map((m) => m.name).toSet();
          return testData.asMap().keys.every((i) => names.contains('$i'));
        },
        timeout: const Duration(seconds: 30),
      );

      // All messages eventually received with correct data
      for (var i = 0; i < testData.length; i++) {
        final msg = receivedMessages.where((m) => m.name == '$i').first;
        expect(msg.data, equals(testData[i]));
      }

      // RTL18c: At least one recovery was triggered
      expect(attachingReasons, isNotEmpty);
      expect(attachingReasons[0]?.code, equals(40018));

      client.close();
    });
  });

  group('PC3 - No plugin causes FAILED state', () {
    test('delta message without plugin transitions channel to FAILED',
        () async {
      final channelName = 'delta-no-plugin-${_randomId()}';

      // Subscriber client — no vcdiff plugin, but requests delta channel param
      final subscriber = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
          autoConnect: false,
        ),
      );

      // Publisher client — separate connection, publishes without delta
      final publisher = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
          autoConnect: false,
        ),
      );

      subscriber.connect();
      publisher.connect();
      await Future.wait([
        _awaitState(subscriber.connection, ConnectionState.connected),
        _awaitState(publisher.connection, ConnectionState.connected),
      ]);

      final subChannel = subscriber.channels.get(
        channelName,
        const RealtimeChannelOptions(params: {'delta': 'vcdiff'}),
      );

      await subChannel.attach();

      // Publisher uses a plain channel (no delta param)
      final pubChannel = publisher.channels.get(channelName);
      await pubChannel.attach();

      // Publish enough messages to trigger delta encoding on subscriber.
      // Don't await individually — fire them off quickly so the subscriber
      // receives deltas before all publishes complete.
      final publishFutures = <Future>[];
      for (var i = 0; i < testData.length; i++) {
        publishFutures.add(
          pubChannel.publish(name: '$i', data: testData[i]),
        );
      }
      // Wait for all publishes to complete (they use a separate connection)
      await Future.wait(publishFutures);

      // Subscriber channel should transition to FAILED when it can't
      // decode a delta (no plugin registered)
      await _waitUntil(
        () => subChannel.state == ChannelState.failed,
        timeout: const Duration(seconds: 15),
      );

      expect(subChannel.state, equals(ChannelState.failed));
      expect(subChannel.errorReason?.code, equals(40019));

      subscriber.close();
      publisher.close();
    });
  });
}

String _randomId() {
  final random = Random();
  return String.fromCharCodes(
    List.generate(6, (_) => random.nextInt(26) + 97),
  );
}

Future<void> _awaitState(
  Connection connection,
  ConnectionState targetState, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  if (connection.state == targetState) return;
  await connection
      .on()
      .firstWhere((change) => change.current == targetState)
      .timeout(timeout);
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 15),
  Duration pollInterval = const Duration(milliseconds: 100),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition not met within $timeout');
    }
    await Future<void>.delayed(pollInterval);
  }
}
