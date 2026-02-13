import 'dart:math';

import 'package:test/test.dart';
import 'package:ably_dart/ably_dart.dart';

import '../../helpers/test_app_helper.dart';

/// Integration tests for REST mutable messages (RSL1n, RSL11, RSL14, RSL15,
/// RSAN1, RSAN2, RSAN3).
///
/// These tests run against the Ably Sandbox environment and verify
/// mutable message operations: publish with serials, getMessage,
/// updateMessage, deleteMessage, appendMessage, getMessageVersions,
/// and annotations.
///
/// Uses ably-common test-app-setup.json:
///   keys[0] — full access (default capability)
///   namespace "mutable" — mutableMessages: true
///
/// Spec: uts/test/rest/integration/mutable_messages.md
void main() {
  late TestApp testApp;
  late String apiKey;
  late Rest client;
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
    client = Rest(
      options: ClientOptions(
        key: apiKey,
        environment: 'sandbox',
        useBinaryProtocol: false,
      ),
    );
    print('Provisioned test app: ${testApp.appId}');
  });

  tearDownAll(() async {
    await client.close();
    await testApp.delete();
    print('Deleted test app: ${testApp.appId}');
  });

  group('RSL1n - publish returns serials from sandbox', () {
    test('single and batch publish return valid serials', () async {
      final channelName = 'mutable:test-RSL1n-${randomId()}';
      final channel = client.channels.get(channelName);

      // Single message
      final result1 = await channel.publish(name: 'event1', data: 'data1');
      expect(result1, isA<PublishResult>());
      expect(result1.serials, isList);
      expect(result1.serials.length, equals(1));
      expect(result1.serials[0], isA<String>());
      expect(result1.serials[0]!.length, greaterThan(0));

      // Batch publish
      final result2 = await channel.publish(
        messages: [
          Message(name: 'event2', data: 'data2'),
          Message(name: 'event3', data: 'data3'),
          Message(name: 'event4', data: 'data4'),
        ],
      );
      expect(result2.serials.length, equals(3));
      for (final serial in result2.serials) {
        expect(serial, isA<String>());
        expect(serial!.length, greaterThan(0));
      }

      // Serials should be unique
      expect(result2.serials[0], isNot(equals(result2.serials[1])));
      expect(result2.serials[1], isNot(equals(result2.serials[2])));
    });
  });

  group('RSL11 - getMessage retrieves published message', () {
    test('published message can be retrieved by serial', () async {
      final channelName = 'mutable:test-RSL11-${randomId()}';
      final channel = client.channels.get(channelName);

      final publishResult =
          await channel.publish(name: 'test-event', data: 'hello world');
      final serial = publishResult.serials[0]!;

      final msg = await channel.getMessage(serial);

      expect(msg, isA<Message>());
      expect(msg.name, equals('test-event'));
      expect(msg.data, equals('hello world'));
      expect(msg.serial, equals(serial));
      expect(msg.action, equals(MessageAction.messageCreate));
      expect(msg.timestamp, isNotNull);
    });
  });

  group('RSL15 - updateMessage updates a published message', () {
    test('update is visible via getMessage', () async {
      final channelName = 'mutable:test-RSL15-update-${randomId()}';
      final channel = client.channels.get(channelName);

      // Publish original
      final publishResult =
          await channel.publish(name: 'original', data: 'original-data');
      final serial = publishResult.serials[0]!;

      // Update
      final updateResult = await channel.updateMessage(
        Message(serial: serial, name: 'updated', data: 'updated-data'),
        operation: MessageOperation(description: 'edited content'),
      );

      expect(updateResult, isA<UpdateDeleteResult>());
      expect(updateResult.versionSerial, isA<String>());
      expect(updateResult.versionSerial!.length, greaterThan(0));

      // Wait for propagation then verify via getMessage
      await waitForPropagation();
      final updatedMsg = await channel.getMessage(serial);
      expect(updatedMsg.name, equals('updated'));
      expect(updatedMsg.data, equals('updated-data'));
      expect(updatedMsg.action, equals(MessageAction.messageUpdate));
      expect(updatedMsg.version!.description, equals('edited content'));
    });
  });

  group('RSL15 - deleteMessage deletes a published message', () {
    test('deleted message shows MESSAGE_DELETE action', () async {
      final channelName = 'mutable:test-RSL15-delete-${randomId()}';
      final channel = client.channels.get(channelName);

      // Publish
      final publishResult =
          await channel.publish(name: 'to-delete', data: 'delete-me');
      final serial = publishResult.serials[0]!;

      // Delete
      final deleteResult = await channel.deleteMessage(
        Message(serial: serial),
      );

      expect(deleteResult, isA<UpdateDeleteResult>());
      expect(deleteResult.versionSerial, isA<String>());
      expect(deleteResult.versionSerial!.length, greaterThan(0));

      // Wait for propagation then verify via getMessage
      await waitForPropagation();
      final deletedMsg = await channel.getMessage(serial);
      expect(deletedMsg.action, equals(MessageAction.messageDelete));
    });
  });

  group('RSL15 - appendMessage appends to a published message', () {
    test('append returns a version serial', () async {
      final channelName = 'mutable:test-RSL15-append-${randomId()}';
      final channel = client.channels.get(channelName);

      // Publish
      final publishResult =
          await channel.publish(name: 'appendable', data: 'original');
      final serial = publishResult.serials[0]!;

      // Append
      final appendResult = await channel.appendMessage(
        Message(serial: serial, data: 'appended-data'),
        operation: MessageOperation(description: 'appended content'),
      );

      expect(appendResult, isA<UpdateDeleteResult>());
      expect(appendResult.versionSerial, isA<String>());
      expect(appendResult.versionSerial!.length, greaterThan(0));
    });
  });

  group('RSL14 - getMessageVersions returns version history', () {
    test('version history contains original and updates', () async {
      final channelName = 'mutable:test-RSL14-${randomId()}';
      final channel = client.channels.get(channelName);

      // Publish original
      final publishResult =
          await channel.publish(name: 'versioned', data: 'v1');
      final serial = publishResult.serials[0]!;

      // Update twice
      await channel.updateMessage(
        Message(serial: serial, data: 'v2'),
        operation: MessageOperation(description: 'first edit'),
      );
      await channel.updateMessage(
        Message(serial: serial, data: 'v3'),
        operation: MessageOperation(description: 'second edit'),
      );

      // Wait for propagation then get version history
      await waitForPropagation();
      final versions = await channel.getMessageVersions(serial);

      expect(versions, isA<PaginatedResult<Message>>());
      expect(versions.items.length, greaterThanOrEqualTo(3));

      // All items should be Messages with the same serial
      for (final item in versions.items) {
        expect(item, isA<Message>());
        expect(item.serial, equals(serial));
      }
    });
  });

  group('RSAN1, RSAN2 - publish and delete annotations', () {
    test('annotation lifecycle: create, verify, delete', () async {
      final channelName = 'mutable:test-RSAN-lifecycle-${randomId()}';
      final channel = client.channels.get(channelName);

      // Publish a message to annotate
      final publishResult =
          await channel.publish(name: 'annotatable', data: 'content');
      final serial = publishResult.serials[0]!;

      // Create an annotation
      await channel.annotations.publish(
        serial,
        Annotation(type: 'com.ably.reactions', name: 'like'),
      );

      // Wait for propagation then verify annotation exists
      await waitForPropagation();
      final annotations = await channel.annotations.get(serial);
      expect(annotations.items.length, greaterThanOrEqualTo(1));

      var found = false;
      for (final ann in annotations.items) {
        if (ann.type == 'com.ably.reactions' && ann.name == 'like') {
          found = true;
          expect(ann.action, equals(AnnotationAction.annotationCreate));
          expect(ann.messageSerial, equals(serial));
        }
      }
      expect(found, isTrue);

      // Delete the annotation
      await channel.annotations.delete(
        serial,
        Annotation(type: 'com.ably.reactions', name: 'like'),
      );
    });
  });

  group('RSAN3 - get annotations returns PaginatedResult', () {
    test('multiple annotations retrieved as paginated result', () async {
      final channelName = 'mutable:test-RSAN3-${randomId()}';
      final channel = client.channels.get(channelName);

      // Publish a message
      final publishResult =
          await channel.publish(name: 'multi-annotated', data: 'content');
      final serial = publishResult.serials[0]!;

      // Publish multiple annotations
      await channel.annotations.publish(
        serial,
        Annotation(type: 'com.ably.reactions', name: 'like'),
      );
      await channel.annotations.publish(
        serial,
        Annotation(type: 'com.ably.reactions', name: 'heart'),
      );

      // Wait for propagation then retrieve annotations
      await waitForPropagation();
      final result = await channel.annotations.get(serial);

      expect(result, isA<PaginatedResult<Annotation>>());
      expect(result.items.length, greaterThanOrEqualTo(2));

      for (final ann in result.items) {
        expect(ann, isA<Annotation>());
        expect(ann.messageSerial, equals(serial));
        expect(ann.type, equals('com.ably.reactions'));
        expect(ann.timestamp, isNotNull);
      }
    });
  });
}
