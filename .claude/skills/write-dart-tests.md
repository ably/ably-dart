---
skill: write-dart-tests
description: Guidelines for implementing Dart test files from UTS test specifications
tags: [testing, dart, ably]
---

# Writing Dart Tests for the Ably Dart SDK

This skill covers how to translate UTS (Universal Test Specification) pseudocode specs into working Dart test files for the ably-dart SDK.

## Relationship to UTS Specs

Every Dart test corresponds to a UTS spec in `../uts/test/`. The UTS spec defines:
- **What** to test (spec points, expected behavior)
- **Test structure** (setup, steps, assertions)
- **Mock patterns** (pseudocode for mock behavior)

This skill covers the **Dart-specific implementation** of those specs.

### Keeping UTS and Dart in Sync

When fixing a bug or gap in a Dart test, **always check if the corresponding UTS spec has the same issue**. Common cases:
- Mock missing a field (e.g. `data: p.data` in echo) — fix in both UTS and Dart
- Loop index bugs (e.g. hardcoded `:0` instead of `:${idx}`) — fix in both
- Test patterns that only work in Dart (e.g. `authCallback` for clientId) — fine to differ, but note in the UTS spec if relevant

Similarly, when updating a UTS spec, check if the Dart test needs a corresponding update.

## File Structure and Conventions

### Test File Location

```
test/
├── helpers/                              # Shared test utilities
│   ├── mock_websocket_client.dart        # MockWebSocketClient
│   ├── mock_http_client.dart             # MockHttpClient
│   ├── fake_timer_manager.dart           # FakeTimerManager + TestClock
│   ├── protocol_message_helpers.dart     # ProtocolMessageHelpers
│   └── test_channel_name.dart            # testChannelName()
├── unit/realtime/
│   ├── channels/                         # Channel tests (RTL*)
│   ├── connection/                       # Connection tests (RTN*)
│   ├── auth/                             # Auth tests (RSA*)
│   └── realtime_client_test.dart         # Client attribute tests (RTC*)
└── integration/realtime/                 # Integration tests (real server)
```

### Test File Template

```dart
import 'dart:async';

import 'package:clock/clock.dart';           // Only if using FakeTimerManager
import 'package:test/test.dart';
import 'package:ably_dart/ably_dart.dart';
import '../../../helpers/fake_timer_manager.dart';       // Only if needed
import '../../../helpers/mock_websocket_client.dart';
import '../../../helpers/protocol_message_helpers.dart';
import '../../../helpers/test_channel_name.dart';         // Only if using channels

/// Unit tests for [Feature Name] ([Spec IDs]).
///
/// These tests use mocked WebSocket to verify [what].
///
/// Spec: uts/test/realtime/unit/[path to spec].md
void main() {
  group('[Spec ID] - [Descriptive name]', () {
    test('[specific behavior being tested]', () async {
      // ... test body
    });
  });
}
```

### Naming Conventions

- **Group names**: `'RTL4a - Attach when already attached is no-op'`
- **Test names**: `'does not send additional ATTACH message'`
- Spec ID comes first, then a dash, then human-readable description.
- Test names describe the *observable behavior*, not implementation details.

## Core Test Infrastructure

### 1. Realtime.forTesting()

All unit tests that need a Realtime client with mocks use this factory:

```dart
final client = Realtime.forTesting(
  options: ClientOptions(
    key: 'appId.keyId:keySecret',
    autoConnect: false,                    // Almost always false in tests
  ),
  webSocketClient: mockWs,                // Required for WS tests
  timerManager: fakeTimers,               // Only for time-dependent tests
  httpClient: mockHttp,                   // Only if testing HTTP behavior
);
```

**Important**: Always set `autoConnect: false` unless you specifically need auto-connect behavior. This prevents the client from immediately connecting and lets you control the connection timing in tests.

For tests that only check attributes (no connection needed), use the public constructor:

```dart
final client = Realtime(
  options: ClientOptions(
    key: 'fake.key:secret',
    autoConnect: false,
  ),
);
```

### 2. MockWebSocketClient

Two modes: **handler-based** (most tests) and **awaitable** (advanced coordination).

#### Handler-Based Pattern (Recommended)

```dart
late final MockWebSocketClient mockWs;
mockWs = MockWebSocketClient(
  onConnectionAttempt: (conn) {
    conn.respondWithSuccess(
      ProtocolMessageHelpers.connected(
        connectionId: 'test-connection',
        connectionKey: 'test-key',
      ),
    );
  },
  onMessageFromClient: (msg) {
    if (msg.action == ProtocolAction.attach) {
      mockWs.activeConnection!.sendToClient(
        ProtocolMessageHelpers.attached(channel: msg.channel!),
      );
    }
  },
);
```

**Why `late final`?** The `onMessageFromClient` closure references `mockWs` itself (to call `mockWs.activeConnection!.sendToClient(...)`). The `late final` pattern allows this self-reference.

**When `late final` is NOT needed**: If you don't reference `mockWs` inside the closures (e.g., `onConnectionAttempt` handlers that just call `conn.respondWith*()`), you can use a plain `final`:

```dart
final mockWs = MockWebSocketClient(
  onConnectionAttempt: (conn) {
    conn.respondWithSuccess(ProtocolMessageHelpers.connected());
  },
);
```

#### Awaitable Pattern (Advanced)

Use when the test needs to coordinate responses with test execution:

```dart
final mockWs = MockWebSocketClient();

// Set up awaitable BEFORE triggering the action
final connAttemptFuture = mockWs.awaitConnectionAttempt();

client.connect();

final pendingConn = await connAttemptFuture;
pendingConn.respondWithSuccess(ProtocolMessageHelpers.connected());
```

**Critical timing rule**: Call `awaitConnectionAttempt()` BEFORE the action that triggers the connection, otherwise you might miss it.

#### Connection Response Methods

| Method | When to use |
|--------|-------------|
| `conn.respondWithSuccess(ProtocolMessage)` | Normal successful connection |
| `conn.respondWithRefused()` | Connection refused (SocketException) |
| `conn.respondWithTimeout()` | Connection timeout (TimeoutException) |
| `conn.respondWithDnsError()` | DNS failure (SocketException) |
| `conn.respondWithError(ProtocolMessage, {thenClose})` | WS connects, then server sends ERROR protocol message |
| `conn.respondWithSilence()` | WS connects but server sends nothing |

#### Sending Messages to Client

```dart
// Normal message (connection stays open)
mockWs.activeConnection!.sendToClient(ProtocolMessageHelpers.heartbeat());

// Message + close (for DISCONNECTED or connection-level ERROR)
mockWs.activeConnection!.sendToClientAndClose(
  ProtocolMessageHelpers.disconnected(error: ErrorInfo(...)),
);

// Unexpected disconnect (no protocol message)
mockWs.activeConnection!.simulateDisconnect();
```

**Key rule**: Use `sendToClientAndClose()` for DISCONNECTED and connection-level ERROR (no channel). Use `sendToClient()` for channel-level ERROR (has channel field) and all normal messages.

#### Always Dispose

```dart
mockWs.dispose();
```

Call at the end of every test. This cleans up stream controllers.

### 3. ProtocolMessageHelpers

Static factory methods for creating protocol messages:

```dart
ProtocolMessageHelpers.connected(
  connectionId: 'conn-id',
  connectionKey: 'conn-key',
  connectionStateTtl: 120000,     // default
  maxIdleInterval: 15000,         // default
)

ProtocolMessageHelpers.error(
  code: 40400,                     // required
  message: 'Not found',           // required
  statusCode: 404,                // optional
  channel: 'my-channel',         // optional - if set, channel-level error
)

ProtocolMessageHelpers.attached(
  channel: 'my-channel',          // required
  channelSerial: 'serial-1',     // optional
  flags: someFlags,               // optional
)

ProtocolMessageHelpers.detached(channel: 'my-channel')
ProtocolMessageHelpers.disconnected(error: ErrorInfo(...))
ProtocolMessageHelpers.heartbeat()
ProtocolMessageHelpers.ack(msgSerial: 0)
ProtocolMessageHelpers.message(channel: 'ch', name: 'event', data: 'data')
ProtocolMessageHelpers.auth(authDetails: ...)
ProtocolMessageHelpers.closed()
```

### 4. FakeTimerManager + TestClock

For tests that depend on time (timeouts, retries, heartbeats, TTL expiry):

```dart
final testClock = TestClock();
final fakeTimers = FakeTimerManager(testClock);

await withClock(testClock, () async {
  final client = Realtime.forTesting(
    options: ClientOptions(
      key: 'appId.keyId:keySecret',
      autoConnect: false,
      disconnectedRetryTimeout: 1000,    // Control retry timing
      realtimeRequestTimeout: 100,       // Control operation timeouts
    ),
    webSocketClient: mockWs,
    timerManager: fakeTimers,
  );

  // ... test setup ...

  // Advance time to trigger timers
  fakeTimers.elapseTime(const Duration(milliseconds: 150));
  await _pumpEventQueue();   // Let scheduled microtasks run

  // ... assertions ...
});
```

**Important**: Always wrap the test body in `await withClock(testClock, () async { ... })` when using `TestClock`. This makes `clock.now()` in production code use the fake clock.

### 5. testChannelName()

Generates unique channel names to prevent test interference:

```dart
final channelName = testChannelName('RTL4a');
// Returns something like: 'test-RTL4a-aB3kLm9p'
```

Always use this for channel tests. Never hardcode channel names.

## Private Helper Functions

These functions are **copy-pasted into each test file** (not shared). This is a deliberate project convention.

### _awaitConnectionState / _awaitState

```dart
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
```

Checks if already in the target state (returns immediately) or waits for a state change event. Use this after triggering an action that should cause a state transition.

### _awaitChannelState

Same pattern for channels:

```dart
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
```

### _pumpEventQueue

```dart
// Standard variant (most tests)
Future<void> _pumpEventQueue() async {
  await Future<void>.delayed(Duration.zero);
}

// Multi-pump variant (heartbeat_test.dart)
Future<void> _pumpEventQueue([int times = 5]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
```

**Why it's needed**: `FakeTimerManager.elapseTime()` fires timer callbacks via `scheduleMicrotask()`. Similarly, `MockWebSocketConnection.close()` calls `listener.onClose()` via `scheduleMicrotask()`. `_pumpEventQueue()` yields to the event loop so these scheduled callbacks execute before the test continues.

**When to use each variant**:
- Single pump: After `fakeTimers.elapseTime()` when only one level of async callbacks is expected
- Multi-pump: When cascading async operations occur (e.g., timer fires -> close() -> onClose -> reconnect)

## Common Test Patterns

### Pattern 1: Connect, Perform Action, Assert

The most common pattern for channel tests:

```dart
test('specific behavior', () async {
  final channelName = testChannelName('RTL4c');

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
      }
    },
  );

  final client = Realtime.forTesting(
    options: ClientOptions(key: 'appId.keyId:keySecret', autoConnect: false),
    webSocketClient: mockWs,
  );

  final channel = client.channels.get(channelName);

  // Connect first
  client.connect();
  await _awaitConnectionState(client.connection, ConnectionState.connected);

  // Perform action
  await channel.attach();

  // Assert
  expect(channel.state, equals(ChannelState.attached));

  mockWs.dispose();
});
```

### Pattern 2: Counting Messages / Capturing Messages

```dart
var attachMessageCount = 0;
final capturedMessages = <ProtocolMessage>[];

late final MockWebSocketClient mockWs;
mockWs = MockWebSocketClient(
  onConnectionAttempt: (conn) { ... },
  onMessageFromClient: (msg) {
    capturedMessages.add(msg);
    if (msg.action == ProtocolAction.attach) {
      attachMessageCount++;
      mockWs.activeConnection!.sendToClient(
        ProtocolMessageHelpers.attached(channel: msg.channel!),
      );
    }
  },
);

// ... test ...

expect(attachMessageCount, equals(1));
expect(capturedMessages[0].action, equals(ProtocolAction.attach));
```

### Pattern 3: Conditional Response Based on Count

```dart
var attachCount = 0;

late final MockWebSocketClient mockWs;
mockWs = MockWebSocketClient(
  onConnectionAttempt: (conn) { ... },
  onMessageFromClient: (msg) {
    if (msg.action == ProtocolAction.attach) {
      attachCount++;
      if (attachCount == 1) {
        // First attach fails
        mockWs.activeConnection!.sendToClient(
          ProtocolMessage(
            action: ProtocolAction.error,
            channel: channelName,
            error: const ErrorInfo(code: 40160, message: 'Denied'),
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
```

### Pattern 4: Recording State Changes

```dart
final stateChanges = <ConnectionState>[];
client.connection.on().listen((change) {
  stateChanges.add(change.current);
});

// ... trigger actions ...

expect(stateChanges, containsAllInOrder([
  ConnectionState.connecting,
  ConnectionState.connected,
  ConnectionState.disconnected,
  ConnectionState.connecting,
  ConnectionState.connected,
]));
```

For channels:

```dart
final stateChanges = <ChannelStateChange>[];
channel.on().listen(stateChanges.add);

// ... trigger actions ...

expect(stateChanges[0].current, equals(ChannelState.attaching));
expect(stateChanges[0].previous, equals(ChannelState.initialized));
expect(stateChanges[1].current, equals(ChannelState.attached));
```

### Pattern 5: Delayed Mock Response

When you need to control when the mock responds:

```dart
onMessageFromClient: (msg) {
  if (msg.action == ProtocolAction.attach) {
    // Don't respond immediately - let the test do something first
  }
},

// ... in test body ...
// Start attach (don't await)
final attachFuture = channel.attach();
await _awaitChannelState(channel, ChannelState.attaching);

// Now manually send response
mockWs.activeConnection!.sendToClient(
  ProtocolMessageHelpers.attached(channel: channelName),
);

await attachFuture;
```

### Pattern 6: Timeout Tests with FakeTimerManager

```dart
test('times out and transitions to suspended', () async {
  final testClock = TestClock();
  final fakeTimers = FakeTimerManager(testClock);

  await withClock(testClock, () async {
    // Setup with short timeout
    final client = Realtime.forTesting(
      options: ClientOptions(
        key: 'appId.keyId:keySecret',
        autoConnect: false,
        realtimeRequestTimeout: 100,
      ),
      webSocketClient: mockWs,
      timerManager: fakeTimers,
    );

    // Register error handler IMMEDIATELY to prevent unhandled errors
    Object? error;
    final future = channel.attach().catchError((Object e) => error = e);

    // Advance past timeout
    fakeTimers.elapseTime(const Duration(milliseconds: 150));
    await _pumpEventQueue();
    await future;

    expect(error, isA<AblyException>());
  });
});
```

**Critical**: When an async operation will fail via timer timeout, use `.catchError()` immediately when calling the operation. If you just `await` it in a try/catch, the error might be thrown from a `scheduleMicrotask` callback and become an unhandled Future error that crashes the test zone.

### Pattern 7: Time-Advancement Loop for Retry Scenarios

When testing multi-retry scenarios where exact timing is implementation-dependent:

```dart
// Trigger disconnect, then advance time in small increments
mockWs.activeConnection!.simulateDisconnect();
await _pumpEventQueue();

for (var i = 0; i < 15; i++) {
  fakeTimers.elapseTime(const Duration(milliseconds: 2500));
  await _pumpEventQueue();
  if (client.connection.state == ConnectionState.connected) {
    break;
  }
}

await _awaitState(client.connection, ConnectionState.connected);
```

### Pattern 8: Testing Error Paths

```dart
// Expect synchronous throw
expect(
  () => channel.attach(),
  throwsA(isA<AblyException>()),
);

// Expect async error
try {
  await channel.attach();
  fail('Expected AblyException');
} catch (e) {
  expect(e, isA<AblyException>());
}
```

### Pattern 9: Connection URL Inspection

```dart
var connectionAttemptCount = 0;
final capturedUrls = <Uri>[];

final mockWs = MockWebSocketClient(
  onConnectionAttempt: (conn) {
    connectionAttemptCount++;
    capturedUrls.add(conn.url);
    conn.respondWithSuccess(ProtocolMessageHelpers.connected(...));
  },
);

// ... trigger connections ...

expect(capturedUrls[1].queryParameters['resume'], equals('key-1'));
```

## Dart-Specific Async Pitfalls

### 1. Broadcast Stream + Sync Controller

The Ably SDK uses `StreamController.broadcast(sync: true)` for state change events. This means:
- Events are delivered *synchronously* during `add()`.
- If a `firstWhere` listener matches, it can resume an `await` chain *inside* the `add()` call.
- This can cause re-entrant `add()` errors or unhandled exceptions.

**Mitigation in tests**: Use `_pumpEventQueue()` after triggering actions to let async continuations settle. Use `.catchError()` instead of try/catch for futures that might error from timer callbacks.

### 2. catchError vs try/catch for Timer-Driven Errors

When `FakeTimerManager.elapseTime()` fires a timer that causes a Future to complete with an error, that error is delivered via `scheduleMicrotask`. If no error handler is registered yet, Dart's test zone reports it as unhandled.

```dart
// BAD - error may fire before try/catch is set up
try {
  fakeTimers.elapseTime(...);
  await _pumpEventQueue();
  await operationFuture;     // Error might already be unhandled
} catch (e) { ... }

// GOOD - register handler immediately
Object? error;
final future = operation().catchError((Object e) => error = e);
fakeTimers.elapseTime(...);
await _pumpEventQueue();
await future;
expect(error, isA<AblyException>());
```

### 3. `scheduleMicrotask` in Mock Responses

`PendingWebSocketConnection.respondWithSuccess()` delivers the CONNECTED message via `scheduleMicrotask`. This means the response is not instant — you need `await` or `_awaitState` after calling it.

Similarly, `MockWebSocketConnection.close()` calls `listener.onClose()` via `scheduleMicrotask`, requiring `_pumpEventQueue()` to process.

### 4. Awaiting Transient States

When multiple state transitions happen quickly (e.g., `disconnected -> connecting -> connected`), you can't reliably `await` the intermediate `disconnected` state because it may have already passed by the time your await is set up.

**Solution**: Record state changes with a listener and verify the sequence afterward:

```dart
final stateChanges = <ConnectionState>[];
client.connection.on().listen((change) {
  stateChanges.add(change.current);
});

// Trigger the behavior
mockWs.activeConnection!.simulateDisconnect();

// Wait for final state
await _awaitState(client.connection, ConnectionState.connected);

// Verify the transient states were hit
expect(stateChanges, containsAllInOrder([
  ConnectionState.disconnected,
  ConnectionState.connecting,
  ConnectionState.connected,
]));
```

## Error Code Guidelines

When test specs need distinctive error codes for provenance verification:
- **Don't** use generic codes like 50000 — they might be generated by other code paths.
- **Do** use specific codes like 40198, 40199 — unlikely to collide with real codes.
- **Don't** use 500 as statusCode for non-server errors — use status codes that match the scenario (e.g., 403 for "account disabled").
- The goal: when the test asserts `error.code == 40198`, we know the error came from our mock, not from some other code path.

## Integration Test Patterns

Integration tests use real Ably sandbox, no mocks:

```dart
// Use the public constructor (not forTesting)
final client = Realtime(
  options: ClientOptions(
    key: 'fake.key:secret',    // or real sandbox key
    autoConnect: false,
  ),
);

client.connect();
await _awaitState(
  client.connection,
  ConnectionState.failed,
  timeout: const Duration(seconds: 10),   // Longer timeouts for network
);
```

Integration tests need longer timeouts and should handle network variability.

## Completion Status Matrix

When adding a new Dart test file, update the completion status matrix at `test/completion-status.md` to reflect the newly covered spec items. This matrix tracks which spec items have Dart tests and cross-references with UTS test spec coverage.

## Checklist for New Test Files

1. Include spec reference comment at top of file
2. Use spec IDs in group/test names
3. Use `autoConnect: false` in ClientOptions
4. Use `testChannelName()` for channel names
5. Use `late final` for MockWebSocketClient when onMessageFromClient references it
6. Call `mockWs.dispose()` at end of each test
7. Add `_awaitConnectionState`, `_awaitChannelState`, `_pumpEventQueue` as private file-level functions (copy from existing test)
8. For timeout tests: use FakeTimerManager + `.catchError()` pattern
9. For state sequence tests: record changes in a list, verify with `containsAllInOrder`
10. Ensure error codes are distinctive enough for provenance assertions
11. Update `test/completion-status.md` when adding new test files
12. Use `Uri.encodeComponent()` for variable path segments in URL assertions — use `equals()` not `contains()`

## Mapping UTS Pseudocode to Dart

| UTS Pseudocode | Dart Implementation |
|---|---|
| `mock_ws = MockWebSocket(onConnectionAttempt: ...)` | `mockWs = MockWebSocketClient(onConnectionAttempt: ...)` |
| `install_mock(mock_ws)` | Pass as `webSocketClient:` to `Realtime.forTesting()` |
| `client = Realtime(options: ...)` | `Realtime.forTesting(options: ..., webSocketClient: mockWs)` |
| `AWAIT_STATE client.connection.state == connected` | `await _awaitConnectionState(client.connection, ConnectionState.connected)` |
| `AWAIT_STATE channel.state == attached` | `await _awaitChannelState(channel, ChannelState.attached)` |
| `ADVANCE_TIME(5000)` | `fakeTimers.elapseTime(const Duration(milliseconds: 5000))` |
| `PUMP_EVENT_QUEUE()` | `await _pumpEventQueue()` |
| `send_to_client(msg)` | `mockWs.activeConnection!.sendToClient(msg)` |
| `send_to_client_and_close(msg)` | `mockWs.activeConnection!.sendToClientAndClose(msg)` |
| `simulate_disconnect()` | `mockWs.activeConnection!.simulateDisconnect()` |
| `ASSERT x == y` | `expect(x, equals(y))` |
| `ASSERT x IS Type` | `expect(x, isA<Type>())` |
| `operation FAILS WITH error` | `try { await op(); fail('Expected error'); } catch (e) { expect(e, isA<AblyException>()); }` |
| `CONTAINS_IN_ORDER [a, b, c]` | `expect(list, containsAllInOrder([a, b, c]))` |
| `enable_fake_timers()` | `final testClock = TestClock(); final fakeTimers = FakeTimerManager(testClock); await withClock(testClock, () async { ... });` |
| `encode_uri_component(value)` | `Uri.encodeComponent(value)` |

## Quick Reference: Imports

```dart
// Always needed
import 'package:test/test.dart';
import 'package:ably_dart/ably_dart.dart';

// Mock WebSocket
import '../../../helpers/mock_websocket_client.dart';
import '../../../helpers/protocol_message_helpers.dart';

// Channels
import '../../../helpers/test_channel_name.dart';

// Time control
import 'dart:async';
import 'package:clock/clock.dart';
import '../../../helpers/fake_timer_manager.dart';

// HTTP mocking (for auth/connectivity tests)
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import '../../../helpers/mock_http_client.dart';
```
