import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:test/test.dart';
import 'package:ably_dart/ably_dart.dart';
import '../../../helpers/fake_timer_manager.dart';
import '../../../helpers/mock_websocket_client.dart';
import '../../../helpers/protocol_message_helpers.dart';
import '../../../helpers/test_channel_name.dart';

/// Unit tests for RealtimeChannel publish (RTL6).
///
/// These tests use mocked WebSocket to verify message publishing,
/// state-dependent queuing/rejection, wire encoding, ACK/NACK handling,
/// and the RTL6c5 rule that publish does not trigger implicit attach.
///
/// Spec: uts/test/realtime/unit/channels/channel_publish.md
void main() {
  // ---------------------------------------------------------------------------
  // RTL6i1 - Publish single message by name and data
  // ---------------------------------------------------------------------------

  group('RTL6i1 - Publish single message by name and data', () {
    test('sends a MESSAGE ProtocolMessage with one message entry', () async {
      final channelName = testChannelName('RTL6i1');
      final capturedMessages = <ProtocolMessage>[];

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(ProtocolMessageHelpers.connected());
        },
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.attach) {
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.attached(channel: channelName),
            );
          } else if (msg.action == ProtocolAction.message) {
            capturedMessages.add(msg);
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.ack(
                msgSerial: msg.msgSerial!,
                count: 1,
                res: [
                  PublishResult(serials: const ['s1']),
                ],
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

      final channel = client.channels.get(
        channelName,
        const RealtimeChannelOptions(attachOnSubscribe: false),
      );

      client.connect();
      await _awaitConnectionState(
        client.connection,
        ConnectionState.connected,
      );
      await channel.attach();

      await channel.publish(name: 'greeting', data: 'hello');

      expect(capturedMessages, hasLength(1));
      expect(capturedMessages[0].action, equals(ProtocolAction.message));
      expect(capturedMessages[0].channel, equals(channelName));
      expect(capturedMessages[0].messages, hasLength(1));

      final msg = capturedMessages[0].messages![0] as Map<String, dynamic>;
      expect(msg['name'], equals('greeting'));
      expect(msg['data'], equals('hello'));

      mockWs.dispose();
    });

    test('publishes a Message object directly', () async {
      final channelName = testChannelName('RTL6i1-obj');
      final capturedMessages = <ProtocolMessage>[];

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(ProtocolMessageHelpers.connected());
        },
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.attach) {
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.attached(channel: channelName),
            );
          } else if (msg.action == ProtocolAction.message) {
            capturedMessages.add(msg);
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.ack(
                msgSerial: msg.msgSerial!,
                count: 1,
                res: [
                  PublishResult(serials: const ['s1']),
                ],
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

      final channel = client.channels.get(
        channelName,
        const RealtimeChannelOptions(attachOnSubscribe: false),
      );

      client.connect();
      await _awaitConnectionState(
        client.connection,
        ConnectionState.connected,
      );
      await channel.attach();

      await channel.publish(
        message: const Message(name: 'custom', data: 'value'),
      );

      expect(capturedMessages, hasLength(1));
      expect(capturedMessages[0].messages, hasLength(1));

      final msg = capturedMessages[0].messages![0] as Map<String, dynamic>;
      expect(msg['name'], equals('custom'));
      expect(msg['data'], equals('value'));

      mockWs.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // RTL6i2 - Publish array of Message objects
  // ---------------------------------------------------------------------------

  group('RTL6i2 - Publish array of Message objects', () {
    test('sends all messages in a single ProtocolMessage', () async {
      final channelName = testChannelName('RTL6i2');
      final capturedMessages = <ProtocolMessage>[];

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(ProtocolMessageHelpers.connected());
        },
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.attach) {
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.attached(channel: channelName),
            );
          } else if (msg.action == ProtocolAction.message) {
            capturedMessages.add(msg);
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.ack(
                msgSerial: msg.msgSerial!,
                count: 1,
                res: [
                  PublishResult(
                    serials: const ['s1', 's2', 's3'],
                  ),
                ],
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

      final channel = client.channels.get(
        channelName,
        const RealtimeChannelOptions(attachOnSubscribe: false),
      );

      client.connect();
      await _awaitConnectionState(
        client.connection,
        ConnectionState.connected,
      );
      await channel.attach();

      await channel.publish(messages: const [
        Message(name: 'event1', data: 'data1'),
        Message(name: 'event2', data: 'data2'),
        Message(name: 'event3', data: 'data3'),
      ]);

      // Single ProtocolMessage with 3 messages
      expect(capturedMessages, hasLength(1));
      expect(capturedMessages[0].messages, hasLength(3));

      final msgs = capturedMessages[0].messages!.cast<Map<String, dynamic>>();
      expect(msgs[0]['name'], equals('event1'));
      expect(msgs[1]['name'], equals('event2'));
      expect(msgs[2]['name'], equals('event3'));

      mockWs.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // RTL6i3 - Null fields omitted from JSON wire encoding
  // ---------------------------------------------------------------------------

  group('RTL6i3 - Null fields omitted from JSON wire encoding', () {
    test('name-only publish omits data key from wire JSON', () async {
      final channelName = testChannelName('RTL6i3-json');
      final capturedFrames = <Map<String, dynamic>>[];
      var msgSerialCounter = 0;

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(ProtocolMessageHelpers.connected());
        },
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.attach) {
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.attached(channel: channelName),
            );
          } else if (msg.action == ProtocolAction.message) {
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.ack(
                msgSerial: msg.msgSerial!,
                count: 1,
                res: [
                  PublishResult(serials: const ['s']),
                ],
              ),
            );
          }
        },
        onTextDataFrame: (text) {
          final decoded = jsonDecode(text) as Map<String, dynamic>;
          // action 15 = MESSAGE
          if (decoded['action'] == 15) {
            capturedFrames.add(decoded);
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

      final channel = client.channels.get(
        channelName,
        const RealtimeChannelOptions(attachOnSubscribe: false),
      );

      client.connect();
      await _awaitConnectionState(
        client.connection,
        ConnectionState.connected,
      );
      await channel.attach();

      // Publish with name only (null data)
      await channel.publish(name: 'click');

      // Publish with data only (null name)
      await channel.publish(data: 'payload');

      // Publish with both null
      await channel.publish();

      expect(capturedFrames, hasLength(3));

      // First: name present, data key absent
      final msg0 =
          (capturedFrames[0]['messages'] as List)[0] as Map<String, dynamic>;
      expect(msg0['name'], equals('click'));
      expect(msg0.containsKey('data'), isFalse);

      // Second: data present, name key absent
      final msg1 =
          (capturedFrames[1]['messages'] as List)[0] as Map<String, dynamic>;
      expect(msg1.containsKey('name'), isFalse);
      expect(msg1['data'], equals('payload'));

      // Third: both keys absent
      final msg2 =
          (capturedFrames[2]['messages'] as List)[0] as Map<String, dynamic>;
      expect(msg2.containsKey('name'), isFalse);
      expect(msg2.containsKey('data'), isFalse);

      mockWs.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // RTL6c1 - Publish immediately when CONNECTED and channel ATTACHED
  // ---------------------------------------------------------------------------

  group('RTL6c1 - Publish immediately when CONNECTED', () {
    test('sends immediately when channel is ATTACHED', () async {
      final channelName = testChannelName('RTL6c1-attached');
      final capturedMessages = <ProtocolMessage>[];

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(ProtocolMessageHelpers.connected());
        },
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.attach) {
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.attached(channel: channelName),
            );
          } else if (msg.action == ProtocolAction.message) {
            capturedMessages.add(msg);
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.ack(
                msgSerial: msg.msgSerial!,
                count: 1,
                res: [
                  PublishResult(serials: const ['s']),
                ],
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

      final channel = client.channels.get(
        channelName,
        const RealtimeChannelOptions(attachOnSubscribe: false),
      );

      client.connect();
      await _awaitConnectionState(
        client.connection,
        ConnectionState.connected,
      );
      await channel.attach();

      expect(client.connection.state, equals(ConnectionState.connected));
      expect(channel.state, equals(ChannelState.attached));

      await channel.publish(name: 'test', data: 'immediate');

      // Sent synchronously (captured by mock)
      expect(capturedMessages, hasLength(1));

      final msg = capturedMessages[0].messages![0] as Map<String, dynamic>;
      expect(msg['name'], equals('test'));
      expect(msg['data'], equals('immediate'));

      mockWs.dispose();
    });

    test('sends immediately when channel is ATTACHING', () async {
      final channelName = testChannelName('RTL6c1-attaching');
      final capturedMessages = <ProtocolMessage>[];

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(ProtocolMessageHelpers.connected());
        },
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.attach) {
            // Don't respond — leave channel in ATTACHING
          } else if (msg.action == ProtocolAction.message) {
            capturedMessages.add(msg);
            // Send ACK so the publish future resolves
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.ack(
                msgSerial: msg.msgSerial!,
                count: 1,
                res: [
                  PublishResult(serials: const ['s']),
                ],
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

      final channel = client.channels.get(
        channelName,
        const RealtimeChannelOptions(attachOnSubscribe: false),
      );

      client.connect();
      await _awaitConnectionState(
        client.connection,
        ConnectionState.connected,
      );

      // Start attach but don't complete it — swallow the eventual timeout
      unawaited(channel.attach().catchError((_) {}));
      await _awaitChannelState(channel, ChannelState.attaching);

      await channel.publish(name: 'while-attaching', data: 'data');

      // ATTACHING is neither SUSPENDED nor FAILED → sent immediately
      expect(capturedMessages, hasLength(1));

      final msg = capturedMessages[0].messages![0] as Map<String, dynamic>;
      expect(msg['name'], equals('while-attaching'));

      mockWs.dispose();
    });

    test('sends immediately when channel is INITIALIZED', () async {
      final channelName = testChannelName('RTL6c1-init');
      final capturedMessages = <ProtocolMessage>[];

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(ProtocolMessageHelpers.connected());
        },
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.message) {
            capturedMessages.add(msg);
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.ack(
                msgSerial: msg.msgSerial!,
                count: 1,
                res: [
                  PublishResult(serials: const ['s']),
                ],
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

      final channel = client.channels.get(
        channelName,
        const RealtimeChannelOptions(attachOnSubscribe: false),
      );

      client.connect();
      await _awaitConnectionState(
        client.connection,
        ConnectionState.connected,
      );

      expect(channel.state, equals(ChannelState.initialized));

      await channel.publish(name: 'before-attach', data: 'data');

      // INITIALIZED is neither SUSPENDED nor FAILED → sent immediately
      expect(capturedMessages, hasLength(1));

      final msg = capturedMessages[0].messages![0] as Map<String, dynamic>;
      expect(msg['name'], equals('before-attach'));

      mockWs.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // RTL6c2 - Publish queued when connection is CONNECTING
  // ---------------------------------------------------------------------------

  group('RTL6c2 - Publish queued when connection not CONNECTED', () {
    test('queues and sends after CONNECTING → CONNECTED', () async {
      final channelName = testChannelName('RTL6c2-connecting');
      final capturedMessages = <ProtocolMessage>[];

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.message) {
            capturedMessages.add(msg);
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.ack(
                msgSerial: msg.msgSerial!,
                count: 1,
                res: [
                  PublishResult(serials: const ['s']),
                ],
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

      final channel = client.channels.get(
        channelName,
        const RealtimeChannelOptions(attachOnSubscribe: false),
      );

      // Set up await BEFORE triggering connect
      final connAttemptFuture = mockWs.awaitConnectionAttempt();

      client.connect();
      await _awaitConnectionState(
        client.connection,
        ConnectionState.connecting,
      );

      // Publish while CONNECTING — should be queued.
      // Don't await yet — it won't resolve until ACK arrives after connection.
      final publishFuture = channel.publish(name: 'queued', data: 'waiting');

      // Not sent yet
      expect(capturedMessages, isEmpty);

      // Complete the connection
      final pendingConn = await connAttemptFuture;
      pendingConn.respondWithSuccess(ProtocolMessageHelpers.connected());
      await _awaitConnectionState(
        client.connection,
        ConnectionState.connected,
      );

      // Now await the publish — ACK will have been sent by onMessageFromClient
      await publishFuture;

      // Queued message now sent
      expect(capturedMessages, hasLength(1));

      final msg = capturedMessages[0].messages![0] as Map<String, dynamic>;
      expect(msg['name'], equals('queued'));
      expect(msg['data'], equals('waiting'));

      mockWs.dispose();
    });

    test('queues when connection is INITIALIZED', () async {
      final channelName = testChannelName('RTL6c2-init');
      final capturedMessages = <ProtocolMessage>[];

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(ProtocolMessageHelpers.connected());
        },
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.message) {
            capturedMessages.add(msg);
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.ack(
                msgSerial: msg.msgSerial!,
                count: 1,
                res: [
                  PublishResult(serials: const ['s']),
                ],
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

      final channel = client.channels.get(
        channelName,
        const RealtimeChannelOptions(attachOnSubscribe: false),
      );

      expect(client.connection.state, equals(ConnectionState.initialized));

      // Publish before connecting — should be queued.
      // Don't await yet — resolves after connection + ACK.
      final publishFuture = channel.publish(name: 'pre-connect', data: 'early');
      expect(capturedMessages, isEmpty);

      // Now connect
      client.connect();
      await _awaitConnectionState(
        client.connection,
        ConnectionState.connected,
      );

      // Await publish — ACK will have arrived
      await publishFuture;

      // Queued message now sent
      expect(capturedMessages, hasLength(1));

      final msg = capturedMessages[0].messages![0] as Map<String, dynamic>;
      expect(msg['name'], equals('pre-connect'));

      mockWs.dispose();
    });

    test('multiple queued messages sent in order', () async {
      final channelName = testChannelName('RTL6c2-order');
      final capturedMessages = <ProtocolMessage>[];

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.message) {
            capturedMessages.add(msg);
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.ack(
                msgSerial: msg.msgSerial!,
                count: 1,
                res: [
                  PublishResult(serials: const ['s']),
                ],
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

      final channel = client.channels.get(
        channelName,
        const RealtimeChannelOptions(attachOnSubscribe: false),
      );

      // Set up await BEFORE triggering connect
      final connAttemptFuture = mockWs.awaitConnectionAttempt();

      client.connect();
      await _awaitConnectionState(
        client.connection,
        ConnectionState.connecting,
      );

      // Queue multiple messages — don't await yet
      final f1 = channel.publish(name: 'first', data: '1');
      final f2 = channel.publish(name: 'second', data: '2');
      final f3 = channel.publish(name: 'third', data: '3');

      expect(capturedMessages, isEmpty);

      // Complete the connection
      final pendingConn = await connAttemptFuture;
      pendingConn.respondWithSuccess(ProtocolMessageHelpers.connected());
      await _awaitConnectionState(
        client.connection,
        ConnectionState.connected,
      );

      // Await all publishes
      await Future.wait([f1, f2, f3]);

      // All messages sent in order
      expect(capturedMessages, hasLength(3));

      final names = capturedMessages
          .map(
            (m) => (m.messages![0] as Map<String, dynamic>)['name'],
          )
          .toList();
      expect(names, equals(['first', 'second', 'third']));

      mockWs.dispose();
    });

    test('fails when queueMessages is false and not CONNECTED', () async {
      final channelName = testChannelName('RTL6c2-noqueue');

      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          // Don't respond — stay CONNECTING
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
          queueMessages: false,
        ),
        webSocketClient: mockWs,
      );

      final channel = client.channels.get(
        channelName,
        const RealtimeChannelOptions(attachOnSubscribe: false),
      );

      client.connect();
      await _awaitConnectionState(
        client.connection,
        ConnectionState.connecting,
      );

      try {
        await channel.publish(name: 'fail', data: 'should-error');
        fail('Expected AblyException');
      } catch (e) {
        expect(e, isA<AblyException>());
      }

      mockWs.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // RTL6c4 - Publish fails in error states
  // ---------------------------------------------------------------------------

  group('RTL6c4 - Publish fails when connection is CLOSED', () {
    test('throws error after close()', () async {
      final channelName = testChannelName('RTL6c4-closed');

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(ProtocolMessageHelpers.connected());
        },
      );

      final client = Realtime.forTesting(
        options: ClientOptions(
          key: 'appId.keyId:keySecret',
          autoConnect: false,
        ),
        webSocketClient: mockWs,
      );

      final channel = client.channels.get(
        channelName,
        const RealtimeChannelOptions(attachOnSubscribe: false),
      );

      client.connect();
      await _awaitConnectionState(
        client.connection,
        ConnectionState.connected,
      );

      await client.close();
      expect(client.connection.state, equals(ConnectionState.closed));

      try {
        await channel.publish(name: 'fail', data: 'should-error');
        fail('Expected AblyException');
      } catch (e) {
        expect(e, isA<AblyException>());
      }

      mockWs.dispose();
    });
  });

  group('RTL6c4 - Publish fails when connection is FAILED', () {
    test('throws error when connection failed', () async {
      final channelName = testChannelName('RTL6c4-failed');

      final mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithError(
            ProtocolMessageHelpers.error(
              code: 80000,
              message: 'Fatal error',
            ),
            thenClose: true,
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

      final channel = client.channels.get(
        channelName,
        const RealtimeChannelOptions(attachOnSubscribe: false),
      );

      client.connect();
      await _awaitConnectionState(
        client.connection,
        ConnectionState.failed,
      );

      try {
        await channel.publish(name: 'fail', data: 'should-error');
        fail('Expected AblyException');
      } catch (e) {
        expect(e, isA<AblyException>());
      }

      mockWs.dispose();
    });
  });

  group('RTL6c4 - Publish fails when connection is SUSPENDED', () {
    test('throws error when connection suspended', () async {
      final channelName = testChannelName('RTL6c4-suspended');

      final testClock = TestClock();
      final fakeTimers = FakeTimerManager(testClock);

      await withClock(testClock, () async {
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
            fallbackHosts: [],
          ),
          webSocketClient: mockWs,
          timerManager: fakeTimers,
        );

        final channel = client.channels.get(
          channelName,
          const RealtimeChannelOptions(attachOnSubscribe: false),
        );

        client.connect();

        // Wait for DISCONNECTED, then advance past connectionStateTtl
        // (default 120s) to reach SUSPENDED
        await _awaitConnectionState(
          client.connection,
          ConnectionState.disconnected,
        );

        fakeTimers.elapseTime(const Duration(seconds: 121));
        await _pumpEventQueue();

        await _awaitConnectionState(
          client.connection,
          ConnectionState.suspended,
        );

        try {
          await channel.publish(name: 'fail', data: 'should-error');
          fail('Expected AblyException');
        } catch (e) {
          expect(e, isA<AblyException>());
        }

        mockWs.dispose();
      });
    });
  });

  group('RTL6c4 - Publish fails when channel is FAILED', () {
    test('throws error when channel is FAILED', () async {
      final channelName = testChannelName('RTL6c4-ch-failed');
      final capturedMessages = <ProtocolMessage>[];

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(ProtocolMessageHelpers.connected());
        },
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.attach) {
            mockWs.activeConnection!.sendToClient(ProtocolMessage(
              action: ProtocolAction.error,
              channel: channelName,
              error: const ErrorInfo(
                code: 40160,
                statusCode: 401,
                message: 'Not permitted',
              ),
            ));
          } else if (msg.action == ProtocolAction.message) {
            capturedMessages.add(msg);
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

      final channel = client.channels.get(
        channelName,
        const RealtimeChannelOptions(attachOnSubscribe: false),
      );

      client.connect();
      await _awaitConnectionState(
        client.connection,
        ConnectionState.connected,
      );

      // Attach fails → channel enters FAILED
      try {
        await channel.attach();
      } catch (_) {}

      expect(channel.state, equals(ChannelState.failed));

      // Publish should fail because channel is FAILED
      try {
        await channel.publish(name: 'fail', data: 'should-error');
        fail('Expected AblyException');
      } catch (e) {
        expect(e, isA<AblyException>());
      }

      // No MESSAGE sent to server
      expect(capturedMessages, isEmpty);

      mockWs.dispose();
    });
  });

  group('RTL6c4 - Publish fails when channel is SUSPENDED', () {
    test('throws error when channel is SUSPENDED', () async {
      final channelName = testChannelName('RTL6c4-ch-suspended');
      final capturedMessages = <ProtocolMessage>[];

      final testClock = TestClock();
      final fakeTimers = FakeTimerManager(testClock);

      await withClock(testClock, () async {
        late final MockWebSocketClient mockWs;
        mockWs = MockWebSocketClient(
          onConnectionAttempt: (conn) {
            conn.respondWithSuccess(ProtocolMessageHelpers.connected());
          },
          onMessageFromClient: (msg) {
            if (msg.action == ProtocolAction.attach) {
              // Don't respond — will timeout to SUSPENDED
            } else if (msg.action == ProtocolAction.message) {
              capturedMessages.add(msg);
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

        final channel = client.channels.get(
          channelName,
          const RealtimeChannelOptions(attachOnSubscribe: false),
        );

        client.connect();
        await _awaitConnectionState(
          client.connection,
          ConnectionState.connected,
        );

        // Start attach — will timeout and channel enters SUSPENDED
        Object? attachError;
        final attachFuture =
            channel.attach().catchError((Object e) => attachError = e);
        fakeTimers.elapseTime(const Duration(milliseconds: 150));
        await _pumpEventQueue();
        await attachFuture;

        expect(attachError, isNotNull);
        expect(channel.state, equals(ChannelState.suspended));

        // Publish should fail because channel is SUSPENDED
        try {
          await channel.publish(name: 'fail', data: 'should-error');
          fail('Expected AblyException');
        } catch (e) {
          expect(e, isA<AblyException>());
        }

        // No MESSAGE sent to server
        expect(capturedMessages, isEmpty);

        mockWs.dispose();
      });
    });
  });

  // ---------------------------------------------------------------------------
  // RTL6c5 - Publish does not trigger implicit attach
  // ---------------------------------------------------------------------------

  group('RTL6c5 - Publish does not trigger implicit attach', () {
    test('channel remains INITIALIZED after publish', () async {
      final channelName = testChannelName('RTL6c5');
      var attachMessageCount = 0;
      final capturedMessages = <ProtocolMessage>[];

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(ProtocolMessageHelpers.connected());
        },
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.attach) {
            attachMessageCount++;
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.attached(channel: channelName),
            );
          } else if (msg.action == ProtocolAction.message) {
            capturedMessages.add(msg);
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.ack(
                msgSerial: msg.msgSerial!,
                count: 1,
                res: [
                  PublishResult(serials: const ['s']),
                ],
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

      final channel = client.channels.get(
        channelName,
        const RealtimeChannelOptions(attachOnSubscribe: false),
      );

      client.connect();
      await _awaitConnectionState(
        client.connection,
        ConnectionState.connected,
      );

      expect(channel.state, equals(ChannelState.initialized));

      await channel.publish(name: 'no-attach', data: 'test');

      // Message was sent (RTL6c1 — CONNECTED, channel not SUSPENDED/FAILED)
      expect(capturedMessages, hasLength(1));

      // Channel remains INITIALIZED — no implicit attach
      expect(channel.state, equals(ChannelState.initialized));
      expect(attachMessageCount, equals(0));

      mockWs.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // RTL6j - Publish returns PublishResult with serials from ACK
  // ---------------------------------------------------------------------------

  group('RTL6j - Publish returns PublishResult', () {
    test('returns PublishResult with serials from ACK', () async {
      final channelName = testChannelName('RTL6j');
      final capturedMessages = <ProtocolMessage>[];

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(ProtocolMessageHelpers.connected());
        },
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.attach) {
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.attached(channel: channelName),
            );
          } else if (msg.action == ProtocolAction.message) {
            capturedMessages.add(msg);
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.ack(
                msgSerial: msg.msgSerial!,
                count: 1,
                res: [
                  PublishResult(serials: const ['abc123']),
                ],
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

      final channel = client.channels.get(
        channelName,
        const RealtimeChannelOptions(attachOnSubscribe: false),
      );

      client.connect();
      await _awaitConnectionState(
        client.connection,
        ConnectionState.connected,
      );
      await channel.attach();

      final result = await channel.publish(name: 'greeting', data: 'hello');

      // Publish should have been sent with msgSerial
      expect(capturedMessages, hasLength(1));
      expect(capturedMessages[0].msgSerial, equals(0));

      // Result should be a PublishResult with serials from ACK
      expect(result, isA<PublishResult>());
      expect(result.serials, hasLength(1));
      expect(result.serials[0], equals('abc123'));

      mockWs.dispose();
    });

    test('returns PublishResult with multiple serials for batch', () async {
      final channelName = testChannelName('RTL6j-batch');
      final capturedMessages = <ProtocolMessage>[];

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(ProtocolMessageHelpers.connected());
        },
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.attach) {
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.attached(channel: channelName),
            );
          } else if (msg.action == ProtocolAction.message) {
            capturedMessages.add(msg);
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.ack(
                msgSerial: msg.msgSerial!,
                count: 1,
                res: [
                  PublishResult(serials: const ['serial-1', null, 'serial-3']),
                ],
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

      final channel = client.channels.get(
        channelName,
        const RealtimeChannelOptions(attachOnSubscribe: false),
      );

      client.connect();
      await _awaitConnectionState(
        client.connection,
        ConnectionState.connected,
      );
      await channel.attach();

      final result = await channel.publish(messages: const [
        Message(name: 'event1', data: 'data1'),
        Message(name: 'event2', data: 'data2'),
        Message(name: 'event3', data: 'data3'),
      ]);

      // Single ProtocolMessage with 3 messages
      expect(capturedMessages, hasLength(1));
      expect(capturedMessages[0].messages, hasLength(3));

      // Result has serials 1:1 with published messages
      expect(result.serials, hasLength(3));
      expect(result.serials[0], equals('serial-1'));
      expect(result.serials[1], isNull); // Conflated message
      expect(result.serials[2], equals('serial-3'));

      mockWs.dispose();
    });

    test('sequential publishes get incrementing msgSerial', () async {
      final channelName = testChannelName('RTL6j-serial');
      final capturedMessages = <ProtocolMessage>[];

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(ProtocolMessageHelpers.connected());
        },
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.attach) {
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.attached(channel: channelName),
            );
          } else if (msg.action == ProtocolAction.message) {
            capturedMessages.add(msg);
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.ack(
                msgSerial: msg.msgSerial!,
                count: 1,
                res: [
                  PublishResult(serials: ['serial-${msg.msgSerial}']),
                ],
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

      final channel = client.channels.get(
        channelName,
        const RealtimeChannelOptions(attachOnSubscribe: false),
      );

      client.connect();
      await _awaitConnectionState(
        client.connection,
        ConnectionState.connected,
      );
      await channel.attach();

      final result1 = await channel.publish(name: 'first', data: '1');
      final result2 = await channel.publish(name: 'second', data: '2');
      final result3 = await channel.publish(name: 'third', data: '3');

      // Each outgoing MESSAGE should have incrementing msgSerial
      expect(capturedMessages, hasLength(3));
      expect(capturedMessages[0].msgSerial, equals(0));
      expect(capturedMessages[1].msgSerial, equals(1));
      expect(capturedMessages[2].msgSerial, equals(2));

      // Each publish resolves with the correct PublishResult
      expect(result1.serials[0], equals('serial-0'));
      expect(result2.serials[0], equals('serial-1'));
      expect(result3.serials[0], equals('serial-2'));

      mockWs.dispose();
    });

    test('NACK results in error', () async {
      final channelName = testChannelName('RTL6j-nack');

      late final MockWebSocketClient mockWs;
      mockWs = MockWebSocketClient(
        onConnectionAttempt: (conn) {
          conn.respondWithSuccess(ProtocolMessageHelpers.connected());
        },
        onMessageFromClient: (msg) {
          if (msg.action == ProtocolAction.attach) {
            mockWs.activeConnection!.sendToClient(
              ProtocolMessageHelpers.attached(channel: channelName),
            );
          } else if (msg.action == ProtocolAction.message) {
            // Respond with NACK
            mockWs.activeConnection!.sendToClient(ProtocolMessage(
              action: ProtocolAction.nack,
              msgSerial: msg.msgSerial,
              count: 1,
              error: const ErrorInfo(
                code: 40160,
                statusCode: 401,
                message: 'Publish rejected',
              ),
            ));
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

      final channel = client.channels.get(
        channelName,
        const RealtimeChannelOptions(attachOnSubscribe: false),
      );

      client.connect();
      await _awaitConnectionState(
        client.connection,
        ConnectionState.connected,
      );
      await channel.attach();

      try {
        await channel.publish(name: 'rejected', data: 'data');
        fail('Expected AblyException');
      } catch (e) {
        expect(e, isA<AblyException>());
        final ablyError = e as AblyException;
        expect(ablyError.errorInfo?.code, equals(40160));
        expect(ablyError.errorInfo?.message, equals('Publish rejected'));
      }

      mockWs.dispose();
    });
  });
}

// ---------------------------------------------------------------------------
// Private helpers (copied per project convention)
// ---------------------------------------------------------------------------

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

Future<void> _pumpEventQueue() async {
  await Future<void>.delayed(Duration.zero);
}
