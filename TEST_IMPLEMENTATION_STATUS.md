# Realtime Connection Tests Implementation Status

## Overview

I've implemented comprehensive Dart tests based on the UTS specifications for Realtime connection lifecycle and failure handling. These tests are currently **not passing** because they require full implementation of:

1. WebSocket transport with dependency injection
2. Connection state machine with timer management
3. Token renewal flows
4. Connection resume logic
5. Mock WebSocket installation mechanism

## Implemented Test Files

### 1. Integration Tests ✅
**File:** `test/integration/realtime/connection_lifecycle_test.dart`

**Spec:** `uts/test/realtime/integration/connection_lifecycle_test.md`

**Test Coverage:**
- ✅ RTN4b, RTN21 - Successful connection via WebSocket (4 tests)
- ✅ RTN4c, RTN12, RTN12a - Graceful connection close (1 test)
- ✅ RTN11, RTN4b - Connect and reconnect cycle (1 test)
- ✅ RTN11e - Connect when already connecting/connected (1 test)

**Status:** Ready to run against Ably Sandbox once implementation is complete

**Key Features:**
- Real Sandbox provisioning/cleanup
- `_awaitState()` helper for async state transitions
- Proper timeout handling
- Connection ID and key validation

### 2. Unit Tests - Connection Opening Failures (RTN14) ✅
**File:** `test/unit/realtime/connection/connection_open_failures_test.dart`

**Spec:** `uts/test/realtime/unit/connection/connection_open_failures_test.md`

**Test Coverage:**
- ✅ RTN14a - Invalid API key → FAILED (1 test)
- ✅ RTN14b - Token error with/without renewal (2 tests)
- ✅ RTN14c - Connection timeout → DISCONNECTED (1 test)
- ✅ RTN14d - Retry after recoverable failure (1 test)
- ✅ RTN14e - DISCONNECTED → SUSPENDED after TTL (1 test)
- ✅ RTN14f - SUSPENDED retries indefinitely (1 test)
- ✅ RTN14g - ERROR with empty channel → FAILED (1 test)

**Total:** 9 test cases

**Status:** All tests marked with `skip` - waiting for:
- WebSocket dependency injection
- Mock installation mechanism
- Timer mocking support
- HTTP client mocking for token renewal

### 3. Unit Tests - Connection Failures When Connected (RTN15) ✅
**File:** `test/unit/realtime/connection/connection_failures_test.dart`

**Spec:** `uts/test/realtime/unit/connection/connection_failures_test.md`

**Test Coverage:**
- ✅ RTN15h1 - DISCONNECTED + token error without renewal → FAILED (1 test)
- ✅ RTN15h2 - DISCONNECTED + token error with renewal → resume (2 tests)
- ✅ RTN15h3 - DISCONNECTED + non-token error → resume (1 test)
- ✅ RTN15j - ERROR with empty channel → FAILED (1 test)
- ✅ RTN15a - Unexpected disconnect → resume (1 test)
- ✅ RTN15b, RTN15c6 - Successful resume with same ID (1 test)
- ✅ RTN15c7 - Failed resume with new ID (1 test)
- ✅ RTN15e - Connection key updated on resume (covered in RTN15b test)
- ✅ RTN15g - State cleared after TTL → fresh connection (1 test)
- ✅ RTN15c5 - ERROR with token error during resume → renew (1 test)
- ✅ RTN15c4 - ERROR with fatal error during resume → FAILED (1 test)

**Total:** 11 test cases

**Status:** All tests marked with `skip` - waiting for:
- WebSocket dependency injection
- Message injection to established connections
- Mock disconnect simulation
- Timer mocking for TTL expiry
- HTTP client mocking for token renewal

## Implementation Requirements

To make these tests pass, the following need to be implemented:

### 1. WebSocket Transport Layer
```dart
// Production WebSocket transport
class RealtimeWebSocketTransport implements WebSocketTransport {
  // Uses dart:io WebSocket or package
}

// Test helper for dependency injection
void installMockWebSocket(MockWebSocketClient mock) {
  // Global or context-based mock installation
}
```

### 2. Connection State Machine
```dart
class ConnectionStateMachine {
  // State transitions with timer management
  // Protocol message handling
  // Token renewal flows
  // Resume/recovery logic
}
```

### 3. Timer Manager Integration
```dart
class MockTimerManager {
  void advanceTime(Duration duration);
  void fire(Object owner, String name);
}
```

### 4. Mock Installation Pattern
The tests assume a pattern like:
```dart
final mockWs = MockWebSocketClient(...);
installMock(mockWs);  // Makes SDK use this mock

final client = Realtime(...);
// Client now uses mockWs internally
```

### 5. Message Injection After Connection
```dart
// Need ability to get reference to active WebSocket connection
final wsConnection = mockWs.getCurrentConnection();

// Then inject server messages
wsConnection.sendToClient(
  ProtocolMessageHelpers.disconnected(...)
);
```

## Test Patterns Used

### State Waiting Helper
```dart
Future<void> _awaitState(
  Connection connection,
  ConnectionState targetState, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  if (connection.state == targetState) return;
  
  await connection
      .on()
      .firstWhere((change) => change.current == targetState)
      .timeout(timeout);
}
```

### Integration Test Pattern
```dart
group('Test group', () {
  test('test description', () async {
    final client = Realtime(
      options: ClientOptions(
        key: apiKey,
        environment: 'sandbox',
      ),
    );
    
    client.connect();
    await _awaitState(client.connection, ConnectionState.connected);
    
    expect(client.connection.id, isNotNull);
    
    await client.close();
  });
});
```

### Unit Test Pattern (with mock)
```dart
test('test description', () async {
  final mockWs = MockWebSocketClient(
    onConnectionAttempt: (conn) {
      conn.respondWithSuccess(
        ProtocolMessageHelpers.connected(...)
      );
    },
  );
  
  installMock(mockWs);  // TODO: Implement
  
  final client = Realtime(...);
  client.connect();
  
  await _awaitState(client.connection, ConnectionState.connected);
  
  expect(client.connection.state, equals(ConnectionState.connected));
}, skip: 'Requires WebSocket dependency injection');
```

## Running Tests

### Integration Tests (when implementation complete)
```bash
# Run against Sandbox
dart test test/integration/realtime/connection_lifecycle_test.dart
```

### Unit Tests (when implementation complete)
```bash
# Run with mocks
dart test test/unit/realtime/connection/connection_open_failures_test.dart
dart test test/unit/realtime/connection/connection_failures_test.dart
```

### All Realtime Tests
```bash
dart test test/unit/realtime/
dart test test/integration/realtime/
```

## Next Steps

1. **Implement WebSocket transport abstraction**
   - `WebSocketTransport` interface
   - Production implementation using `dart:io` WebSocket
   - Dependency injection pattern

2. **Implement mock installation mechanism**
   - Global mock registry or context-based injection
   - Allow tests to install `MockWebSocketClient`

3. **Implement ConnectionStateMachine**
   - State transitions following REALTIME_DESIGN.md
   - Timer management integration
   - Protocol message handling

4. **Add timer mocking support**
   - `MockTimerManager` for deterministic timer control
   - `advanceTime()` and `fire()` methods

5. **Add message injection capabilities**
   - Access to active WebSocket connection from mock
   - `sendToClient()` method for protocol messages

6. **Implement token renewal flows**
   - Auth integration with HTTP mocking
   - Token expiry handling (RTN14b, RTN15h2)

7. **Implement resume logic**
   - Connection key management
   - Resume parameter in URLs
   - State clearing after TTL (RTN15g)

## Test Statistics

- **Total Test Cases:** 27
- **Integration Tests:** 7
- **Unit Tests (RTN14):** 9
- **Unit Tests (RTN15):** 11
- **Currently Passing:** 0 (all skipped pending implementation)
- **Test Coverage:** RTN4b, RTN4c, RTN11, RTN11e, RTN12, RTN12a, RTN14(a-g), RTN15(a,b,c4,c5,c6,c7,e,g,h1,h2,h3,j), RTN21

## Documentation

- **UTS Specs:** `uts/test/realtime/`
- **Design Doc:** `REALTIME_DESIGN.md`
- **Implementation Status:** This document
- **API Reference:** Based on `ably-flutter` API

## Notes

All tests are written following best practices:
- ✅ Clear test names describing what is being tested
- ✅ Proper setup/teardown with resource cleanup
- ✅ Timeout handling to prevent hanging tests
- ✅ Skip reasons documenting what's needed
- ✅ Helper functions for common patterns
- ✅ Comments indicating TODOs for full implementation

The tests serve as:
1. **Executable specification** of required behavior
2. **Regression prevention** once implementation is complete
3. **Documentation** of expected API behavior
4. **Development guide** showing what needs to be built
