import 'dart:async';

import 'package:clock/clock.dart';
import 'package:test/test.dart';
import 'package:ably_dart/ably_dart.dart';
import '../../../helpers/fake_timer_manager.dart';
import '../../../helpers/mock_websocket_client.dart';
import '../../../helpers/protocol_message_helpers.dart';
import '../../../helpers/test_channel_name.dart';

/// Unit tests for RealtimeChannel attach (RTL4).
///
/// These tests use mocked WebSocket to verify channel attach behavior
/// including state transitions, protocol messages, and error handling.
///
/// Spec: uts/test/realtime/unit/channels/channel_attach.md
void main() {
  group('RTL4a - Attach when already attached is no-op', () {
    test('does not send additional ATTACH message', () async {
      final channelName = testChannelName('RTL4a');
      var attachMessageCount = 0;

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(),
          );
        },
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.attach) {
            attachMessageCount++;
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.attached(channel: channelName),
            );
          }
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      final channel = client.channels.get(channelName);

      client.connect();
      await _awaitConnectionState(client.connection, ConnectionState.connected);

      // First attach
      await channel.attach();
      expect(channel.state, equals(ChannelState.attached));
      expect(attachMessageCount, equals(1));

      // Second attach - should be no-op
      await channel.attach();
      expect(channel.state, equals(ChannelState.attached));
      expect(attachMessageCount, equals(1));

      mockWs.dispose();
    });
  });

  group('RTL4h - Attach while attaching waits for completion', () {
    test('only sends one ATTACH message', () async {
      final channelName = testChannelName('RTL4h');
      var attachMessageCount = 0;

      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(),
          );
        },
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.attach) {
            attachMessageCount++;
            // Don't respond immediately - let second attach() call happen
          }
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      final channel = client.channels.get(channelName);

      client.connect();
      await _awaitConnectionState(client.connection, ConnectionState.connected);

      // Start first attach (don't await)
      final attachFuture1 = channel.attach();

      // Wait for attaching state
      await _awaitChannelState(channel, ChannelState.attaching);

      // Start second attach while first is pending
      final attachFuture2 = channel.attach();

      // Now send ATTACHED response
      mockWs.activeConnection!.sendToClient(
        ProtocolMessageHelpers.attached(channel: channelName),
      );

      // Both should complete
      await attachFuture1;
      await attachFuture2;

      expect(channel.state, equals(ChannelState.attached));
      expect(attachMessageCount, equals(1));

      mockWs.dispose();
    });
  });

  group('RTL4h - Attach while detaching waits then attaches', () {
    test('sends ATTACH after DETACH completes', () async {
      final channelName = testChannelName('RTL4h-detaching');
      final messagesFromClient = <ProtocolMessage>[];

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(),
          );
        },
        onMessageFromClient: (msg) {
          messagesFromClient.add(msg);
          if (msg.action == ProtocolAction.attach) {
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.attached(channel: channelName),
            );
          }
          // Don't auto-respond to DETACH - we'll do it manually
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      final channel = client.channels.get(channelName);

      client.connect();
      await _awaitConnectionState(client.connection, ConnectionState.connected);

      // Attach first
      await channel.attach();
      expect(channel.state, equals(ChannelState.attached));

      // Start detach (don't await)
      final detachFuture = channel.detach();
      await _awaitChannelState(channel, ChannelState.detaching);

      // Start attach while detaching
      final attachFuture = channel.attach();

      // Send DETACHED response
      mockWs.activeConnection!.sendToClient(
        ProtocolMessageHelpers.detached(channel: channelName),
      );

      await detachFuture;

      // Now ATTACH should be sent and complete
      await attachFuture;

      expect(channel.state, equals(ChannelState.attached));

      // Should have: ATTACH, DETACH, ATTACH
      final attachMessages =
          messagesFromClient.where((m) => m.action == ProtocolAction.attach);
      expect(attachMessages.length, equals(2));

      mockWs.dispose();
    });
  });

  group('RTL4g - Attach from failed state clears errorReason', () {
    test('clears error and proceeds with attach', () async {
      final channelName = testChannelName('RTL4g');
      var attachCount = 0;

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(),
          );
        },
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.attach) {
            attachCount++;
            if (attachCount == 1) {
              // First attach fails
              mockWs.activeConnection!.sendToClient(
                ProtocolMessage(
                  action: ProtocolAction.error,
                  channel: channelName,
                  error: ErrorInfo(code: 40160, message: 'Denied'),
                ),
              );
            } else {
              // Second attach succeeds
              mockWs.activeConnection!.sendToClient(
                ProtocolMessageHelpers.attached(channel: channelName),
              );
            }
          }
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      final channel = client.channels.get(channelName);

      client.connect();
      await _awaitConnectionState(client.connection, ConnectionState.connected);

      // First attach fails
      try {
        await channel.attach();
      } catch (_) {
        // Expected
      }
      expect(channel.state, equals(ChannelState.failed));
      expect(channel.errorReason, isNotNull);

      // Second attach from failed state
      await channel.attach();

      expect(channel.state, equals(ChannelState.attached));
      expect(channel.errorReason, isNull);

      mockWs.dispose();
    });
  });

  group('RTL4b - Attach fails when connection is closed', () {
    test('returns error when connection is closed', () async {
      final channelName = testChannelName('RTL4b-closed');

      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(),
          );
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      final channel = client.channels.get(channelName);

      client.connect();
      await _awaitConnectionState(client.connection, ConnectionState.connected);

      // Close the connection
      await client.close();
      expect(client.connection.state, equals(ConnectionState.closed));

      // Try to attach - should fail
      expect(
        () => channel.attach(),
        throwsA(isA<AblyException>()),
      );

      expect(channel.state, isNot(equals(ChannelState.attached)));

      mockWs.dispose();
    });
  });

  group('RTL4b - Attach fails when connection is suspended', () {
    test('returns error when connection is suspended', () async {
      final testClock = TestClock();
      final fakeTimers = FakeTimerManager(testClock);

      await withClock(testClock, () async {
        final channelName = testChannelName('RTL4b-suspended');

        final mockWs = MockWebSocketClient(
          onConnectionAttempt: (conn) {
            conn.respondWithRefused();
          },
        );

        final client = Realtime.forTesting(
          options: ClientOptions(
            key: 'appId.keyId:keySecret',
            autoConnect: false,
            disconnectedRetryTimeout: 1000,
            suspendedRetryTimeout: 100,
            fallbackHosts: [],
          ),
          webSocketClient: mockWs,
          timerManager: fakeTimers,
        );

        final channel = client.channels.get(channelName);

        client.connect();
        await _awaitConnectionState(
          client.connection,
          ConnectionState.disconnected,
        );

        // Advance past connectionStateTtl to reach suspended
        fakeTimers.elapseTime(const Duration(seconds: 121));
        await _pumpEventQueue();

        expect(client.connection.state, equals(ConnectionState.suspended));

        // Try to attach - should fail
        expect(
          () => channel.attach(),
          throwsA(isA<AblyException>()),
        );

        expect(channel.state, isNot(equals(ChannelState.attached)));

        mockWs.dispose();
      });
    });
  });

  group('RTL4b - Attach fails when connection is failed', () {
    test('returns error when connection is failed', () async {
      final channelName = testChannelName('RTL4b-failed');

      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithError(
            ProtocolMessageHelpers.error(
              code: 80000,
              message: 'Fatal error',
              statusCode: 400,
            ),
          );
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      final channel = client.channels.get(channelName);

      client.connect();
      await _awaitConnectionState(client.connection, ConnectionState.failed);

      // Try to attach - should fail
      expect(
        () => channel.attach(),
        throwsA(isA<AblyException>()),
      );

      expect(channel.state, isNot(equals(ChannelState.attached)));

      mockWs.dispose();
    });
  });

  group('RTL4i - Attach queued when connection is connecting', () {
    test('channel enters attaching when connection is connecting', () async {
      final channelName = testChannelName('RTL4i');

      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          // Don't respond - leave connection in connecting state
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      final channel = client.channels.get(channelName);

      // Start connecting but don't complete
      client.connect();
      await _awaitConnectionState(
        client.connection,
        ConnectionState.connecting,
      );

      // Start attach while connection is still connecting
      // ignore: unawaited_futures
      channel.attach();

      // Channel should enter attaching
      await _awaitChannelState(channel, ChannelState.attaching);
      expect(channel.state, equals(ChannelState.attaching));

      mockWs.dispose();
    });

    test('attach completes when connection becomes connected', () async {
      final channelName = testChannelName('RTL4i-connected');
      var attachMessageReceived = false;

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          // Don't respond immediately
        },
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.attach) {
            attachMessageReceived = true;
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.attached(channel: channelName),
            );
          }
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      final channel = client.channels.get(channelName);

      // Set up awaitable before connecting to avoid broadcast stream race
      final connAttemptFuture = mockWs.awaitConnectionAttempt();

      // Start connecting
      client.connect();
      await _awaitConnectionState(
        client.connection,
        ConnectionState.connecting,
      );

      // Start attach while connecting
      final attachFuture = channel.attach();
      await _awaitChannelState(channel, ChannelState.attaching);
      expect(attachMessageReceived, isFalse);

      // Complete connection
      final pendingConn = await connAttemptFuture;
      pendingConn.respondWithSuccess(ProtocolMessageHelpers.connected());

      // Attach should complete
      await attachFuture;

      expect(channel.state, equals(ChannelState.attached));
      expect(attachMessageReceived, isTrue);

      mockWs.dispose();
    });
  });

  group('RTL4c - Attach sends ATTACH message and transitions to attaching', () {
    test('sends ATTACH protocol message with correct channel', () async {
      final channelName = testChannelName('RTL4c');
      ProtocolMessage? capturedAttachMessage;

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(),
          );
        },
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.attach) {
            capturedAttachMessage = msg;
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.attached(channel: channelName),
            );
          }
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      final channel = client.channels.get(channelName);

      ChannelState? stateDuringAttach;
      channel.on(ChannelEvent.attaching).listen((change) {
        stateDuringAttach = change.current;
      });

      client.connect();
      await _awaitConnectionState(client.connection, ConnectionState.connected);

      await channel.attach();

      expect(stateDuringAttach, equals(ChannelState.attaching));
      expect(channel.state, equals(ChannelState.attached));
      expect(capturedAttachMessage, isNotNull);
      expect(capturedAttachMessage!.action, equals(ProtocolAction.attach));
      expect(capturedAttachMessage!.channel, equals(channelName));

      mockWs.dispose();
    });
  });

  group('RTL4c1 - ATTACH includes channelSerial when available', () {
    test('first attach has no channelSerial, reattach includes it', () async {
      final channelName = testChannelName('RTL4c1');
      final capturedAttachMessages = <ProtocolMessage>[];

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(),
          );
        },
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.attach) {
            capturedAttachMessages.add(msg);
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.attached(
                channel: channelName,
                channelSerial: 'serial-from-server-1',
              ),
            );
          }
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      final channel = client.channels.get(channelName);

      client.connect();
      await _awaitConnectionState(client.connection, ConnectionState.connected);

      // First attach - no channelSerial yet
      await channel.attach();

      // Trigger reattach via setOptions (RTL16a) — does NOT go through
      // DETACHED, so channelSerial is preserved (RTL15b1 only clears on
      // DETACHED/SUSPENDED/FAILED).
      await channel.setOptions(
        const RealtimeChannelOptions(modes: [ChannelMode.subscribe]),
      );

      expect(capturedAttachMessages.length, equals(2));
      // First attach has no channelSerial
      expect(capturedAttachMessages[0].channelSerial, isNull);
      // Second attach (reattach via setOptions) includes channelSerial
      expect(
        capturedAttachMessages[1].channelSerial,
        equals('serial-from-server-1'),
      );

      mockWs.dispose();
    });
  });

  group('RTL4f - Attach times out and transitions to suspended', () {
    test('transitions to suspended when no ATTACHED received', () async {
      final testClock = TestClock();
      final fakeTimers = FakeTimerManager(testClock);

      await withClock(testClock, () async {
        final channelName = testChannelName('RTL4f');

        final mockWs = MockWebSocketClient(
          onConnectionAttempt: (conn) {
            conn.respondWithSuccess(
              ProtocolMessageHelpers.connected(),
            );
          },
          onMessageFromClient: (msg) {
            if (msg.action == ProtocolAction.attach) {
              // Don't respond - simulate timeout
            }
          },
        );

        final client = Realtime.forTesting(
          options: ClientOptions(
            key: 'appId.keyId:keySecret',
            autoConnect: false,
            realtimeRequestTimeout: 100,
          ),
          webSocketClient: mockWs,
          timerManager: fakeTimers,
        );

        final channel = client.channels.get(channelName);

        client.connect();
        await _awaitConnectionState(
          client.connection,
          ConnectionState.connected,
        );

        // Register error handler immediately so completeError from the
        // async timeout callback doesn't become unhandled.
        Object? attachError;
        final attachFuture =
            channel.attach().catchError((Object e) => attachError = e);

        // Advance time past timeout
        fakeTimers.elapseTime(const Duration(milliseconds: 150));
        await _pumpEventQueue();
        await attachFuture;

        expect(attachError, isA<AblyException>());
        expect(channel.state, equals(ChannelState.suspended));

        mockWs.dispose();
      });
    });
  });

  group('RTL4k - ATTACH includes params from ChannelOptions', () {
    test('channel params are included in ATTACH message', () async {
      final channelName = testChannelName('RTL4k');
      ProtocolMessage? capturedAttachMessage;

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(),
          );
        },
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.attach) {
            capturedAttachMessage = msg;
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.attached(channel: channelName),
            );
          }
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      final channelOptions = const RealtimeChannelOptions(
        params: {'rewind': '1', 'delta': 'vcdiff'},
      );
      final channel = client.channels.get(channelName, channelOptions);

      client.connect();
      await _awaitConnectionState(client.connection, ConnectionState.connected);

      await channel.attach();

      expect(capturedAttachMessage, isNotNull);
      expect(capturedAttachMessage!.params, isNotNull);
      expect(capturedAttachMessage!.params!['rewind'], equals('1'));
      expect(capturedAttachMessage!.params!['delta'], equals('vcdiff'));

      mockWs.dispose();
    });
  });

  group('RTL4l - ATTACH includes modes as flags', () {
    test('channel modes are encoded in ATTACH flags', () async {
      final channelName = testChannelName('RTL4l');
      ProtocolMessage? capturedAttachMessage;

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(),
          );
        },
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.attach) {
            capturedAttachMessage = msg;
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.attached(channel: channelName),
            );
          }
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      final channelOptions = const RealtimeChannelOptions(
        modes: [ChannelMode.publish, ChannelMode.subscribe],
      );
      final channel = client.channels.get(channelName, channelOptions);

      client.connect();
      await _awaitConnectionState(client.connection, ConnectionState.connected);

      await channel.attach();

      expect(capturedAttachMessage, isNotNull);
      expect(capturedAttachMessage!.flags, isNotNull);
      expect(
        capturedAttachMessage!.flags! & ChannelMode.publish.flagBit,
        isNot(0),
        reason: 'PUBLISH bit should be set (TR3r)',
      );
      expect(
        capturedAttachMessage!.flags! & ChannelMode.subscribe.flagBit,
        isNot(0),
        reason: 'SUBSCRIBE bit should be set (TR3s)',
      );

      mockWs.dispose();
    });
  });

  group('RTL4m - Channel modes populated from ATTACHED response', () {
    test('modes are decoded from ATTACHED flags', () async {
      final channelName = testChannelName('RTL4m');
      // PUBLISH (TR3r) + SUBSCRIBE (TR3s)
      final responseFlags =
          ChannelMode.publish.flagBit | ChannelMode.subscribe.flagBit;

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(),
          );
        },
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.attach) {
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.attached(
                channel: channelName,
                flags: responseFlags,
              ),
            );
          }
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      final channel = client.channels.get(channelName);

      client.connect();
      await _awaitConnectionState(client.connection, ConnectionState.connected);

      await channel.attach();

      expect(channel.modes, isNotNull);
      expect(channel.modes, contains(ChannelMode.publish));
      expect(channel.modes, contains(ChannelMode.subscribe));

      mockWs.dispose();
    });
  });

  group('RTL4j - ATTACH_RESUME flag set for reattach', () {
    test('first attach has no ATTACH_RESUME, reattach has it', () async {
      final channelName = testChannelName('RTL4j');
      final capturedAttachMessages = <ProtocolMessage>[];

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(
            ProtocolMessageHelpers.connected(),
          );
        },
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.attach) {
            capturedAttachMessages.add(msg);
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.attached(channel: channelName),
            );
          } else if (msg.action == ProtocolAction.detach) {
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.detached(channel: channelName),
            );
          }
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      final channel = client.channels.get(channelName);

      client.connect();
      await _awaitConnectionState(client.connection, ConnectionState.connected);

      // First attach - clean attach
      await channel.attach();

      // Detach
      await channel.detach();

      // Reattach - should have ATTACH_RESUME flag
      await channel.attach();

      expect(capturedAttachMessages.length, equals(2));
      // First attach should NOT have ATTACH_RESUME flag (TR3f)
      expect(
        (capturedAttachMessages[0].flags ?? 0) & flagAttachResume,
        equals(0),
      );
      // Second attach SHOULD have ATTACH_RESUME flag (TR3f)
      expect(
        (capturedAttachMessages[1].flags ?? 0) & flagAttachResume,
        isNot(0),
      );

      mockWs.dispose();
    });
  });
}

/// Waits for connection to reach the specified state.
Future<void> _awaitConnectionState(
  Connection connection,
  ConnectionState targetState, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  if (connection.state == targetState) {
    return;
  }

  await connection
      .on()
      .firstWhere((change) => change.current == targetState)
      .timeout(timeout);
}

/// Waits for channel to reach the specified state.
Future<void> _awaitChannelState(
  RealtimeChannel channel,
  ChannelState targetState, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  if (channel.state == targetState) {
    return;
  }

  await channel
      .on()
      .firstWhere((change) => change.current == targetState)
      .timeout(timeout);
}

/// Pumps the event queue to allow async operations to complete.
Future<void> _pumpEventQueue() async {
  await Future<void>.delayed(Duration.zero);
}
