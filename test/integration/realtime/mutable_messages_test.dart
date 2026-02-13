import 'dart:async';
import 'dart:math';

import 'package:test/test.dart';
import 'package:ably_dart/ably_dart.dart';

import '../../helpers/test_app_helper.dart';

/// Integration tests for Realtime mutable messages and annotations.
///
/// These tests run against the Ably Sandbox environment and verify:
/// - Update/delete/append via MESSAGE ProtocolMessage (RTL32)
/// - Real-time delivery of mutation events to subscribers
/// - getMessage and getMessageVersions from RealtimeChannel (RTL28, RTL31)
/// - Annotation publish/delete via ANNOTATION ProtocolMessage (RTAN1, RTAN2)
/// - Annotation subscribe with type filtering (RTAN4)
/// - Implicit attach from annotations.subscribe (RTAN4d)
///
/// Spec: uts/test/realtime/integration/mutable_messages_test.md
void main() {
  late TestApp testApp;
  late String apiKey;
  final random = Random();

  String randomId() {
    final bytes = List<int>.generate(6, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Wait for eventual consistency in the sandbox.
  Future<void> waitForPropagation() =>
      Future<void>.delayed(const Duration(seconds: 2));

  setUpAll(() async {
    testApp = await TestApp.provision();
    apiKey = testApp.keys[0].keyStr;
    print('Provisioned test app: ${testApp.appId}');
  });

  tearDownAll(() async {
    await testApp.delete();
    print('Deleted test app: ${testApp.appId}');
  });

  group('RTL32 - Update a message via realtime and observe on subscriber', () {
    test('update event delivered to subscriber in real-time', () async {
      final channelName = 'mutable:rt-update-${randomId()}';

      final clientA = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      final clientB = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      try {
        clientA.connect();
        await _awaitConnectionState(
            clientA.connection, ConnectionState.connected);
        clientB.connect();
        await _awaitConnectionState(
            clientB.connection, ConnectionState.connected);

        final channelA = clientA.channels.get(channelName);
        final channelB = clientB.channels.get(channelName);

        await channelB.attach();

        final receivedMessages = <Message>[];
        channelB.subscribe((msg) => receivedMessages.add(msg));

        await channelA.attach();

        // Publish original message
        await channelA.publish(name: 'original', data: 'v1');

        await _pollUntil(
          () => receivedMessages.length >= 1,
          timeout: const Duration(seconds: 10),
        );

        final serial = receivedMessages[0].serial!;

        // Update via realtime
        final updateResult = await channelA.updateMessage(
          Message(serial: serial, name: 'updated', data: 'v2'),
          operation: MessageOperation(description: 'edited'),
        );

        await _pollUntil(
          () => receivedMessages.length >= 2,
          timeout: const Duration(seconds: 10),
        );

        // Assertions
        expect(updateResult, isA<UpdateDeleteResult>());
        expect(updateResult.versionSerial, isA<String>());
        expect(updateResult.versionSerial!.length, greaterThan(0));

        expect(receivedMessages[0].action, equals(MessageAction.messageCreate));
        expect(receivedMessages[0].name, equals('original'));
        expect(receivedMessages[0].data, equals('v1'));
        expect(receivedMessages[0].serial, isNotEmpty);

        final updateMsg = receivedMessages[1];
        expect(updateMsg.action, equals(MessageAction.messageUpdate));
        expect(updateMsg.name, equals('updated'));
        expect(updateMsg.data, equals('v2'));
        expect(updateMsg.serial, equals(serial));
      } finally {
        await clientA.close();
        await clientB.close();
      }
    });
  });

  group('RTL32 - Delete a message via realtime and observe on subscriber', () {
    test('delete event delivered to subscriber in real-time', () async {
      final channelName = 'mutable:rt-delete-${randomId()}';

      final clientA = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      final clientB = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      try {
        clientA.connect();
        await _awaitConnectionState(
            clientA.connection, ConnectionState.connected);
        clientB.connect();
        await _awaitConnectionState(
            clientB.connection, ConnectionState.connected);

        final channelA = clientA.channels.get(channelName);
        final channelB = clientB.channels.get(channelName);

        await channelB.attach();

        final receivedMessages = <Message>[];
        channelB.subscribe((msg) => receivedMessages.add(msg));

        await channelA.attach();

        // Publish original
        await channelA.publish(name: 'to-delete', data: 'ephemeral');

        await _pollUntil(
          () => receivedMessages.length >= 1,
          timeout: const Duration(seconds: 10),
        );

        final serial = receivedMessages[0].serial!;

        // Delete via realtime
        final deleteResult =
            await channelA.deleteMessage(Message(serial: serial));

        await _pollUntil(
          () => receivedMessages.length >= 2,
          timeout: const Duration(seconds: 10),
        );

        expect(deleteResult, isA<UpdateDeleteResult>());
        expect(deleteResult.versionSerial, isA<String>());
        expect(deleteResult.versionSerial!.length, greaterThan(0));

        final deleteMsg = receivedMessages[1];
        expect(deleteMsg.action, equals(MessageAction.messageDelete));
        expect(deleteMsg.serial, equals(serial));
      } finally {
        await clientA.close();
        await clientB.close();
      }
    });
  });

  group('RTL32 - Append to a message via realtime and observe on subscriber',
      () {
    test('append event delivered to subscriber in real-time', () async {
      final channelName = 'mutable:rt-append-${randomId()}';

      final clientA = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      final clientB = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      try {
        clientA.connect();
        await _awaitConnectionState(
            clientA.connection, ConnectionState.connected);
        clientB.connect();
        await _awaitConnectionState(
            clientB.connection, ConnectionState.connected);

        final channelA = clientA.channels.get(channelName);
        final channelB = clientB.channels.get(channelName);

        await channelB.attach();

        final receivedMessages = <Message>[];
        channelB.subscribe((msg) => receivedMessages.add(msg));

        await channelA.attach();

        // Publish original
        await channelA.publish(name: 'appendable', data: 'original');

        await _pollUntil(
          () => receivedMessages.length >= 1,
          timeout: const Duration(seconds: 10),
        );

        final serial = receivedMessages[0].serial!;

        // Append via realtime
        final appendResult = await channelA.appendMessage(
          Message(serial: serial, data: 'appended-data'),
          operation: MessageOperation(description: 'thread reply'),
        );

        await _pollUntil(
          () => receivedMessages.length >= 2,
          timeout: const Duration(seconds: 10),
        );

        expect(appendResult, isA<UpdateDeleteResult>());
        expect(appendResult.versionSerial, isA<String>());
        expect(appendResult.versionSerial!.length, greaterThan(0));

        final appendMsg = receivedMessages[1];
        expect(appendMsg.action, equals(MessageAction.messageAppend));
        expect(appendMsg.data, equals('appended-data'));
        expect(appendMsg.serial, equals(serial));
      } finally {
        await clientA.close();
        await clientB.close();
      }
    });
  });

  group('RTL32 - Full mutation lifecycle: update, append, delete in sequence',
      () {
    test('all mutation events received in order', () async {
      final channelName = 'mutable:rt-lifecycle-${randomId()}';

      final clientA = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      final clientB = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      try {
        clientA.connect();
        await _awaitConnectionState(
            clientA.connection, ConnectionState.connected);
        clientB.connect();
        await _awaitConnectionState(
            clientB.connection, ConnectionState.connected);

        final channelA = clientA.channels.get(channelName);
        final channelB = clientB.channels.get(channelName);

        await channelB.attach();

        final receivedMessages = <Message>[];
        channelB.subscribe((msg) => receivedMessages.add(msg));

        await channelA.attach();

        // 1. Publish original
        await channelA.publish(name: 'lifecycle', data: 'v1');

        await _pollUntil(
          () => receivedMessages.length >= 1,
          timeout: const Duration(seconds: 10),
        );

        final serial = receivedMessages[0].serial!;

        // 2. Update
        await channelA.updateMessage(
          Message(serial: serial, name: 'lifecycle', data: 'v2'),
          operation: MessageOperation(description: 'edit 1'),
        );

        await _pollUntil(
          () => receivedMessages.length >= 2,
          timeout: const Duration(seconds: 10),
        );

        // 3. Append
        await channelA.appendMessage(
          Message(serial: serial, data: 'reply-data'),
          operation: MessageOperation(description: 'thread reply'),
        );

        await _pollUntil(
          () => receivedMessages.length >= 3,
          timeout: const Duration(seconds: 10),
        );

        // 4. Delete
        await channelA.deleteMessage(Message(serial: serial));

        await _pollUntil(
          () => receivedMessages.length >= 4,
          timeout: const Duration(seconds: 10),
        );

        // Assertions
        expect(receivedMessages.length, equals(4));

        // Create
        expect(receivedMessages[0].action, equals(MessageAction.messageCreate));
        expect(receivedMessages[0].name, equals('lifecycle'));
        expect(receivedMessages[0].data, equals('v1'));
        expect(receivedMessages[0].serial, equals(serial));

        // Update
        expect(receivedMessages[1].action, equals(MessageAction.messageUpdate));
        expect(receivedMessages[1].name, equals('lifecycle'));
        expect(receivedMessages[1].data, equals('v2'));
        expect(receivedMessages[1].serial, equals(serial));

        // Append
        expect(receivedMessages[2].action, equals(MessageAction.messageAppend));
        expect(receivedMessages[2].data, equals('reply-data'));
        expect(receivedMessages[2].serial, equals(serial));

        // Delete
        expect(receivedMessages[3].action, equals(MessageAction.messageDelete));
        expect(receivedMessages[3].serial, equals(serial));
      } finally {
        await clientA.close();
        await clientB.close();
      }
    });
  });

  group(
      'RTL28, RTL31 - getMessage and getMessageVersions from realtime channel',
      () {
    test('HTTP reads work from a RealtimeChannel instance', () async {
      final channelName = 'mutable:rt-get-versions-${randomId()}';

      final client = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      try {
        client.connect();
        await _awaitConnectionState(
            client.connection, ConnectionState.connected);

        final channel = client.channels.get(channelName);
        await channel.attach();

        final receivedMessages = <Message>[];
        channel.subscribe((msg) => receivedMessages.add(msg));

        // Publish original
        await channel.publish(name: 'versioned', data: 'v1');

        await _pollUntil(
          () => receivedMessages.length >= 1,
          timeout: const Duration(seconds: 10),
        );

        final serial = receivedMessages[0].serial!;

        // Update twice
        await channel.updateMessage(
          Message(serial: serial, data: 'v2'),
          operation: MessageOperation(description: 'first edit'),
        );
        await channel.updateMessage(
          Message(serial: serial, data: 'v3'),
          operation: MessageOperation(description: 'second edit'),
        );

        // Wait for propagation before HTTP-based reads
        await waitForPropagation();

        // getMessage — should return latest version
        final msg = await channel.getMessage(serial);

        expect(msg, isA<Message>());
        expect(msg.serial, equals(serial));
        expect(msg.data, equals('v3'));
        expect(msg.action, equals(MessageAction.messageUpdate));

        // getMessageVersions — should return version history
        final versions = await channel.getMessageVersions(serial);

        expect(versions, isA<PaginatedResult<Message>>());
        expect(versions.items.length, greaterThanOrEqualTo(3));

        for (final item in versions.items) {
          expect(item, isA<Message>());
          expect(item.serial, equals(serial));
        }
      } finally {
        await client.close();
      }
    });
  });

  group(
      'RTAN1, RTAN2, RTAN4 - Annotation publish, subscribe, and delete via realtime',
      () {
    test('annotations delivered to subscriber in real-time', () async {
      final channelName = 'mutable:rt-annotations-${randomId()}';

      final clientA = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      final clientB = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      try {
        clientA.connect();
        await _awaitConnectionState(
            clientA.connection, ConnectionState.connected);
        clientB.connect();
        await _awaitConnectionState(
            clientB.connection, ConnectionState.connected);

        final channelA = clientA.channels.get(
          channelName,
          RealtimeChannelOptions(modes: [
            ChannelMode.annotationPublish,
            ChannelMode.annotationSubscribe,
            ChannelMode.publish,
            ChannelMode.subscribe,
          ]),
        );
        final channelB = clientB.channels.get(
          channelName,
          RealtimeChannelOptions(modes: [
            ChannelMode.annotationSubscribe,
            ChannelMode.subscribe,
          ]),
        );

        await channelB.attach();

        // Subscribe to annotations on client B
        final receivedAnnotations = <Annotation>[];
        channelB.annotations.subscribe((ann) => receivedAnnotations.add(ann));

        // Subscribe to messages on client A to capture serial
        final receivedMessages = <Message>[];
        channelA.subscribe((msg) => receivedMessages.add(msg));

        await channelA.attach();

        // Publish a message to annotate
        await channelA.publish(name: 'annotatable', data: 'content');

        await _pollUntil(
          () => receivedMessages.length >= 1,
          timeout: const Duration(seconds: 10),
        );

        final serial = receivedMessages[0].serial!;

        // Publish an annotation via realtime
        await channelA.annotations.publish(
          serial,
          Annotation(type: 'com.ably.reactions', name: 'like'),
        );

        await _pollUntil(
          () => receivedAnnotations.length >= 1,
          timeout: const Duration(seconds: 10),
        );

        // Delete the annotation via realtime
        await channelA.annotations.delete(
          serial,
          Annotation(type: 'com.ably.reactions', name: 'like'),
        );

        await _pollUntil(
          () => receivedAnnotations.length >= 2,
          timeout: const Duration(seconds: 10),
        );

        // Assertions
        expect(receivedAnnotations.length, equals(2));

        final createAnn = receivedAnnotations[0];
        expect(createAnn.action, equals(AnnotationAction.annotationCreate));
        expect(createAnn.type, equals('com.ably.reactions'));
        expect(createAnn.name, equals('like'));
        expect(createAnn.messageSerial, equals(serial));

        final deleteAnn = receivedAnnotations[1];
        expect(deleteAnn.action, equals(AnnotationAction.annotationDelete));
        expect(deleteAnn.type, equals('com.ably.reactions'));
        expect(deleteAnn.name, equals('like'));
        expect(deleteAnn.messageSerial, equals(serial));
      } finally {
        await clientA.close();
        await clientB.close();
      }
    });
  });

  group('RTAN4c - Annotation subscribe with type filtering', () {
    test('filtered subscriber only receives matching annotation types',
        () async {
      final channelName = 'mutable:rt-ann-filter-${randomId()}';

      final clientA = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      final clientB = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      try {
        clientA.connect();
        await _awaitConnectionState(
            clientA.connection, ConnectionState.connected);
        clientB.connect();
        await _awaitConnectionState(
            clientB.connection, ConnectionState.connected);

        final channelA = clientA.channels.get(
          channelName,
          RealtimeChannelOptions(modes: [
            ChannelMode.annotationPublish,
            ChannelMode.annotationSubscribe,
            ChannelMode.publish,
            ChannelMode.subscribe,
          ]),
        );
        final channelB = clientB.channels.get(
          channelName,
          RealtimeChannelOptions(modes: [
            ChannelMode.annotationSubscribe,
            ChannelMode.subscribe,
          ]),
        );

        await channelB.attach();

        // Filtered subscriber: only "com.ably.reactions"
        final filteredAnnotations = <Annotation>[];
        channelB.annotations.subscribe(
          (ann) => filteredAnnotations.add(ann),
          type: 'com.ably.reactions',
        );

        // Unfiltered subscriber: all annotations
        final allAnnotations = <Annotation>[];
        channelB.annotations.subscribe((ann) => allAnnotations.add(ann));

        final receivedMessages = <Message>[];
        channelA.subscribe((msg) => receivedMessages.add(msg));

        await channelA.attach();

        // Publish a message
        await channelA.publish(name: 'multi-type', data: 'content');

        await _pollUntil(
          () => receivedMessages.length >= 1,
          timeout: const Duration(seconds: 10),
        );

        final serial = receivedMessages[0].serial!;

        // Publish annotations of different types
        await channelA.annotations.publish(
          serial,
          Annotation(type: 'com.ably.reactions', name: 'like'),
        );
        await channelA.annotations.publish(
          serial,
          Annotation(type: 'com.example.comments', name: 'comment'),
        );
        await channelA.annotations.publish(
          serial,
          Annotation(type: 'com.ably.reactions', name: 'heart'),
        );

        // Wait for all 3 to arrive on unfiltered listener
        await _pollUntil(
          () => allAnnotations.length >= 3,
          timeout: const Duration(seconds: 10),
        );

        // Unfiltered got all 3
        expect(allAnnotations.length, equals(3));

        // Filtered got only the 2 "com.ably.reactions" annotations
        expect(filteredAnnotations.length, equals(2));
        expect(filteredAnnotations[0].type, equals('com.ably.reactions'));
        expect(filteredAnnotations[0].name, equals('like'));
        expect(filteredAnnotations[1].type, equals('com.ably.reactions'));
        expect(filteredAnnotations[1].name, equals('heart'));
      } finally {
        await clientA.close();
        await clientB.close();
      }
    });
  });

  group('RTAN4d - Annotation subscribe implicitly attaches channel', () {
    test('subscribe triggers implicit attach', () async {
      final channelName = 'mutable:rt-ann-implicit-attach-${randomId()}';

      final client = Realtime(
        options: ClientOptions(
          key: apiKey,
          environment: 'sandbox',
          useBinaryProtocol: false,
        ),
      );

      try {
        client.connect();
        await _awaitConnectionState(
            client.connection, ConnectionState.connected);

        final channel = client.channels.get(
          channelName,
          RealtimeChannelOptions(modes: [
            ChannelMode.annotationSubscribe,
          ]),
        );

        // Channel should be initialized (not attached)
        expect(channel.state, equals(ChannelState.initialized));

        // Subscribe to annotations — should trigger implicit attach
        channel.annotations.subscribe((ann) {
          // no-op
        });

        // Wait for channel to become attached
        await _awaitChannelState(channel, ChannelState.attached);

        expect(channel.state, equals(ChannelState.attached));
      } finally {
        await client.close();
      }
    });
  });
}

/// Waits for connection to reach the specified state.
Future<void> _awaitConnectionState(
  Connection connection,
  ConnectionState targetState, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  if (connection.state == targetState) return;

  final completer = Completer<void>();
  late StreamSubscription<ConnectionStateChange> subscription;

  subscription = connection.on().listen((stateChange) {
    if (stateChange.current == targetState) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  });

  try {
    await completer.future.timeout(timeout);
  } finally {
    await subscription.cancel();
  }
}

/// Waits for channel to reach the specified state.
Future<void> _awaitChannelState(
  RealtimeChannel channel,
  ChannelState targetState, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  if (channel.state == targetState) return;

  final completer = Completer<void>();
  late StreamSubscription<ChannelStateChange> subscription;

  subscription = channel.on().listen((stateChange) {
    if (stateChange.current == targetState) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  });

  try {
    await completer.future.timeout(timeout);
  } finally {
    await subscription.cancel();
  }
}

/// Polls a condition until it returns true.
Future<void> _pollUntil(
  bool Function() condition, {
  Duration interval = const Duration(milliseconds: 200),
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException(
        'Condition not met within ${timeout.inSeconds}s',
        timeout,
      );
    }
    await Future<void>.delayed(interval);
  }
}
