import 'dart:convert';

import 'package:ably_dart/ably_dart.dart';
import 'package:test/test.dart';

import '../../../helpers/test_channel_name.dart';

/// Tests for ChannelOptions and derived channels.
///
/// Spec: TB2, TB3, TB4, RTS3b, RTS3c, RTS3c1, RTS5, RTL16
void main() {
  group('RealtimeChannelOptions - UTS Tests', () {
    group('TB2 - ChannelOptions attributes', () {
      test('default values', () {
        const options = RealtimeChannelOptions();

        expect(options.cipherParams, isNull);
        expect(options.params, isNull);
        expect(options.modes, isNull);
        expect(options.attachOnSubscribe, isTrue);
      });

      test('TB2c - params attribute', () {
        final options = RealtimeChannelOptions(
          params: {'rewind': '1', 'delta': 'vcdiff'},
        );

        expect(options.params!['rewind'], equals('1'));
        expect(options.params!['delta'], equals('vcdiff'));
      });

      test('TB2d - modes attribute', () {
        final options = RealtimeChannelOptions(
          modes: [ChannelMode.publish, ChannelMode.subscribe],
        );

        expect(options.modes, contains(ChannelMode.publish));
        expect(options.modes, contains(ChannelMode.subscribe));
        expect(options.modes!.length, equals(2));
      });

      test('TB4 - attachOnSubscribe default is true', () {
        const options1 = RealtimeChannelOptions();
        const options2 = RealtimeChannelOptions(attachOnSubscribe: false);

        expect(options1.attachOnSubscribe, isTrue);
        expect(options2.attachOnSubscribe, isFalse);
      });
    });

    group('TB3 - withCipherKey constructor', () {
      test('creates options with cipher params from base64 key', () {
        // 256-bit key (32 bytes) as base64
        final key = base64.encode(List.filled(32, 0x42));
        final options = RealtimeChannelOptions.withCipherKey(key);

        expect(options.cipherParams, isNotNull);
        expect(options.cipherParams!.algorithm, equals('aes'));
        expect(options.cipherParams!.keyLength, equals(256));
      });
    });

    group('requiresReattachment', () {
      test('returns false when no params or modes', () {
        const options = RealtimeChannelOptions(
          attachOnSubscribe: false,
        );

        expect(options.requiresReattachment, isFalse);
      });

      test('returns true when params is set', () {
        final options = RealtimeChannelOptions(
          params: {'rewind': '1'},
        );

        expect(options.requiresReattachment, isTrue);
      });

      test('returns true when modes is set', () {
        final options = RealtimeChannelOptions(
          modes: [ChannelMode.subscribe],
        );

        expect(options.requiresReattachment, isTrue);
      });
    });
  });

  group('DeriveOptions - UTS Tests', () {
    test('DO2a - filter attribute', () {
      const deriveOptions = DeriveOptions(
        filter: "name == 'event' && data.count > 10",
      );

      expect(
        deriveOptions.filter,
        equals("name == 'event' && data.count > 10"),
      );
    });
  });

  group('RealtimeChannels with options - UTS Tests', () {
    late Realtime client;

    setUp(() {
      client = Realtime(
        options: ClientOptions(
          key: 'fake.key:secret',
          autoConnect: false,
        ),
      );
    });

    group('RTS3b - Options set on new channel', () {
      test('get() with options sets them on new channel', () {
        final channelName = testChannelName('RTS3b');
        final channelOptions = RealtimeChannelOptions(
          params: {'rewind': '1'},
          modes: [ChannelMode.subscribe],
        );

        final channel = client.channels.get(channelName, channelOptions);

        expect(channel.options.params!['rewind'], equals('1'));
        expect(channel.options.modes, contains(ChannelMode.subscribe));
      });
    });

    group('RTS3c - Options updated on existing channel', () {
      test('get() with options updates existing channel (no reattachment)', () {
        final channelName = testChannelName('RTS3c');

        // Create channel with initial options
        const initialOptions = RealtimeChannelOptions(attachOnSubscribe: false);
        final channel = client.channels.get(channelName, initialOptions);

        // Update with new options that don't require reattachment
        final key = base64.encode(List.filled(32, 0x42));
        final newOptions = RealtimeChannelOptions.withCipherKey(key).copyWith(
          attachOnSubscribe: true,
        );
        final sameChannel = client.channels.get(channelName, newOptions);

        expect(identical(sameChannel, channel), isTrue);
        expect(channel.options.cipherParams, isNotNull);
        expect(channel.options.attachOnSubscribe, isTrue);
      });
    });

    group('RTS3c1 - Error if options would trigger reattachment', () {
      test('throws error when params change on attached channel', () async {
        final channelName = testChannelName('RTS3c1');

        // Create and attach channel
        final channel = client.channels.get(channelName);
        await channel.attach();
        expect(channel.state, equals(ChannelState.attached));

        // Try to update with options that require reattachment
        final newOptions = RealtimeChannelOptions(
          params: {'rewind': '1'},
        );

        expect(
          () => client.channels.get(channelName, newOptions),
          throwsA(isA<AblyException>().having(
            (e) => e.code,
            'code',
            equals(40000),
          )),
        );

        // Channel options should not have changed
        expect(channel.options.params, isNull);
      });

      test('throws error when modes change on attached channel', () async {
        final channelName = testChannelName('RTS3c1-modes');

        final channel = client.channels.get(channelName);
        await channel.attach();

        final newOptions = RealtimeChannelOptions(
          modes: [ChannelMode.subscribe],
        );

        expect(
          () => client.channels.get(channelName, newOptions),
          throwsA(isA<AblyException>()),
        );
      });

      test('allows non-reattachment options on attached channel', () async {
        final channelName = testChannelName('RTS3c1-allowed');

        final channel = client.channels.get(channelName);
        await channel.attach();

        // Options without params/modes should be allowed
        const newOptions = RealtimeChannelOptions(attachOnSubscribe: false);
        final sameChannel = client.channels.get(channelName, newOptions);

        expect(identical(sameChannel, channel), isTrue);
        expect(channel.options.attachOnSubscribe, isFalse);
      });
    });

    group('RTL16 - setOptions', () {
      test('updates channel options', () async {
        final channelName = testChannelName('RTL16');
        final channel = client.channels.get(channelName);

        final newOptions = RealtimeChannelOptions(
          params: {'delta': 'vcdiff'},
          attachOnSubscribe: false,
        );
        await channel.setOptions(newOptions);

        expect(channel.options.params!['delta'], equals('vcdiff'));
        expect(channel.options.attachOnSubscribe, isFalse);
      });

      test('RTL16a - triggers reattachment when params change on attached',
          () async {
        final channelName = testChannelName('RTL16a');
        final channel = client.channels.get(channelName);
        await channel.attach();
        expect(channel.state, equals(ChannelState.attached));

        final stateChanges = <ChannelStateChange>[];
        final subscription = channel.on().listen(stateChanges.add);

        final newOptions = RealtimeChannelOptions(
          params: {'rewind': '1'},
        );
        await channel.setOptions(newOptions);

        // Should have gone through attaching state
        expect(
          stateChanges.any((c) => c.current == ChannelState.attaching),
          isTrue,
        );
        expect(channel.state, equals(ChannelState.attached));
        expect(channel.options.params!['rewind'], equals('1'));

        await subscription.cancel();
      });

      test('does not trigger reattachment when only cipher changes', () async {
        final channelName = testChannelName('RTL16-cipher');
        final channel = client.channels.get(channelName);
        await channel.attach();

        final stateChanges = <ChannelStateChange>[];
        final subscription = channel.on().listen(stateChanges.add);

        // Cipher-only change should not require reattachment
        final key = base64.encode(List.filled(32, 0x42));
        final newOptions = RealtimeChannelOptions.withCipherKey(key);
        await channel.setOptions(newOptions);

        // Should not have gone through attaching state
        expect(
          stateChanges.any((c) => c.current == ChannelState.attaching),
          isFalse,
        );
        expect(channel.options.cipherParams, isNotNull);

        await subscription.cancel();
      });
    });

    group('RTS5 - getDerived', () {
      test('RTS5a - creates derived channel', () {
        final baseChannelName = testChannelName('RTS5a');
        const deriveOptions = DeriveOptions(filter: "name == 'foo'");
        final channel =
            client.channels.getDerived(baseChannelName, deriveOptions);

        expect(channel.name, startsWith('[filter='));
        expect(channel.name, endsWith(']$baseChannelName'));
      });

      test('RTS5a1 - filter is base64 encoded in channel name', () {
        final baseChannelName = testChannelName('RTS5a1');
        const filter = "name == 'test'";
        const deriveOptions = DeriveOptions(filter: filter);
        final channel =
            client.channels.getDerived(baseChannelName, deriveOptions);

        final expectedEncoded = base64.encode(utf8.encode(filter));
        expect(
            channel.name, equals('[filter=$expectedEncoded]$baseChannelName'));
      });

      test('RTS5a2 - params included in derived channel name', () {
        final baseChannelName = testChannelName('RTS5a2');
        const deriveOptions = DeriveOptions(filter: "type == 'message'");
        final channelOptions = RealtimeChannelOptions(
          params: {'rewind': '1'},
        );

        final channel = client.channels.getDerived(
          baseChannelName,
          deriveOptions,
          channelOptions,
        );

        expect(channel.name, contains('[filter='));
        expect(channel.name, contains('?rewind=1'));
        expect(channel.name, endsWith(']$baseChannelName'));
      });

      test('RTS5a2 - multiple params in derived channel name', () {
        final baseChannelName = testChannelName('RTS5a2-multi');
        const deriveOptions = DeriveOptions(filter: 'true');
        final channelOptions = RealtimeChannelOptions(
          params: {'rewind': '1', 'delta': 'vcdiff'},
        );

        final channel = client.channels.getDerived(
          baseChannelName,
          deriveOptions,
          channelOptions,
        );

        // Parse the channel name to verify params without depending on order
        expect(channel.name, endsWith(']$baseChannelName'));

        // Extract qualifier between [ and ]
        final qualifierMatch = RegExp(r'\[(.+)\]').firstMatch(channel.name);
        expect(qualifierMatch, isNotNull);
        final qualifier = qualifierMatch!.group(1)!;

        // Verify filter is present
        expect(qualifier, startsWith('filter='));

        // Extract and parse params
        expect(qualifier, contains('?'));
        final paramsString = qualifier.split('?')[1];
        final parsedParams = Uri.splitQueryString(paramsString);

        expect(parsedParams['rewind'], equals('1'));
        expect(parsedParams['delta'], equals('vcdiff'));
        expect(parsedParams.length, equals(2));
      });

      test('options passed to derived channel', () {
        final baseChannelName = testChannelName('RTS5-options');
        const deriveOptions = DeriveOptions(filter: 'true');
        final channelOptions = RealtimeChannelOptions(
          modes: [ChannelMode.subscribe],
          attachOnSubscribe: false,
        );

        final channel = client.channels.getDerived(
          baseChannelName,
          deriveOptions,
          channelOptions,
        );

        expect(channel.options.modes, contains(ChannelMode.subscribe));
        expect(channel.options.attachOnSubscribe, isFalse);
      });

      test('derived channel is tracked in channels collection', () {
        final baseChannelName = testChannelName('RTS5-tracked');
        const deriveOptions = DeriveOptions(filter: 'true');
        final channel =
            client.channels.getDerived(baseChannelName, deriveOptions);

        expect(client.channels.exists(channel.name), isTrue);
      });
    });
  });

  group('ChannelMode enum - UTS Tests', () {
    test('TB2d - all modes exist', () {
      expect(ChannelMode.values, contains(ChannelMode.presence));
      expect(ChannelMode.values, contains(ChannelMode.publish));
      expect(ChannelMode.values, contains(ChannelMode.subscribe));
      expect(ChannelMode.values, contains(ChannelMode.messageSubscribe));
      expect(ChannelMode.values, contains(ChannelMode.presenceSubscribe));
      expect(ChannelMode.values, contains(ChannelMode.objectSubscribe));
      expect(ChannelMode.values, contains(ChannelMode.objectPublish));
    });
  });
}
