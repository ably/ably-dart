# Architecture

## Overview

The ably-dart SDK implements the [Ably client library specification](https://sdk.ably.com/builds/ably/specification/main/features/) in pure Dart. It provides both REST and Realtime clients with clean separation of concerns and comprehensive testability.

## Design Principles

1. **Simplicity over purity** - Minimal abstraction layers, direct use of Dart idioms
2. **Explicit dependency injection** - No globals, everything injectable for testing
3. **Interface/Implementation split** - Clean public APIs with testable implementations
4. **Shared infrastructure** - REST and Realtime share common code (auth, HTTP)

## Directory Structure

```
lib/src/
├── rest/                      # REST client interface
│   └── rest.dart
├── realtime/                  # Realtime client interface + state management
│   ├── realtime.dart
│   ├── connection.dart        # Connection state machine
│   ├── websocket_client.dart  # WebSocket interface
│   └── io_websocket_client.dart
├── impl/                      # Concrete implementations
│   ├── rest_impl.dart
│   ├── realtime_impl.dart
│   ├── auth_impl.dart         # Shared by both clients
│   └── http/
│       └── http_client.dart   # Shared HTTP client
├── auth/                      # Authentication types
├── channels/                  # Channel interfaces
├── message/                   # Message types
└── error/                     # Error types
```

## Component Architecture

### REST Client

```
┌─────────────────────────────────────────────────┐
│ Rest (Interface)                                │
│ - Factory constructor                           │
│ - Properties: auth, channels, options          │
│ - Methods: time(), request(), batchPublish()   │
└─────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────┐
│ RestImpl                                        │
│ - Dependency injection: http.Client            │
│ - Delegates to:                                │
│   - AuthImpl (authentication)                  │
│   - AblyHttpClient (HTTP operations)           │
│   - RestChannelsImpl (channel management)      │
└─────────────────────────────────────────────────┘
```

**Key characteristics:**
- Stateless (each request is independent)
- Synchronous HTTP requests with futures
- Simple dependency injection via constructor

### Realtime Client

```
┌─────────────────────────────────────────────────┐
│ Realtime (Interface)                            │
│ - Factory constructors:                         │
│   - Realtime()                   (public)      │
│   - Realtime.forTesting()        (@visibleForTesting) │
│ - Properties: connection, channels, auth       │
│ - Methods: connect(), close()                  │
└─────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────┐
│ RealtimeImpl                                    │
│ - Dependency injection:                        │
│   - WebSocketClient (for connections)          │
│   - http.Client (for auth/token renewal)       │
│   - TimerManager (for scheduling)              │
│ - Delegates to:                                │
│   - Connection (state machine)                 │
│   - AuthImpl (authentication)                  │
│   - RealtimeChannels (channel management)      │
└─────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────┐
│ Connection (State Machine)                      │
│ - State: ConnectionState (8 states)            │
│ - WebSocket management                         │
│ - Protocol message handling                    │
│ - Timer management (timeout, retry)            │
│ - Observable: Stream<ConnectionStateChange>    │
└─────────────────────────────────────────────────┘
```

**Key characteristics:**
- Stateful (maintains persistent connection)
- Connection IS the state machine (merged for simplicity)
- Complex dependency injection via forTesting() factory
- Observable state changes via Streams

## Shared Infrastructure

### Authentication (AuthImpl)

Both REST and Realtime use the same `AuthImpl` class:

```dart
AuthImpl({
  required ClientOptions options,
  required AblyHttpClient httpClient,
})
```

**Handles:**
- API key authentication (Basic auth)
- Token authentication
- Token callbacks
- Auth URLs
- Automatic token renewal

### HTTP Client (AblyHttpClient)

Wraps `http.Client` with Ably-specific functionality:

```dart
AblyHttpClient({
  required ClientOptions options,
  http.Client? httpClient,  // Injectable for testing
})
```

**Handles:**
- Request ID generation
- Fallback host retry
- Authentication header injection
- Response parsing
- Error classification

## Dependency Injection Pattern

### REST Client (Simple)

```dart
// Production
final client = Rest(
  options: ClientOptions.fromKey('api-key'),
);

// Testing
final mockHttp = MockHttpClient(...);
final client = Rest(
  options: ClientOptions.fromKey('api-key'),
  httpClient: mockHttp,  // Inject mock
);
```

### Realtime Client (Complex)

```dart
// Production
final client = Realtime(
  options: ClientOptions.fromKey('api-key'),
);

// Testing (@visibleForTesting factory)
final mockWs = MockWebSocketClient(...);
final mockHttp = MockHttpClient(...);
final mockTimer = TimerManager(...);

final client = Realtime.forTesting(
  options: ClientOptions.fromKey('api-key'),
  webSocketClient: mockWs,    // Inject WebSocket mock
  httpClient: mockHttp,        // Inject HTTP mock (optional)
  timerManager: mockTimer,     // Inject timer mock (optional)
);
```

**Why forTesting():**
- Realtime needs multiple injectable dependencies
- Don't want to pollute public API with test concerns
- `@visibleForTesting` annotation signals intent
- Follows Dart testing best practices

## WebSocket Abstraction

**Interface:**
```dart
abstract class WebSocketClient {
  Future<WebSocketConnection> connect(Uri url);
}

abstract class WebSocketConnection {
  Stream<ProtocolMessage> get messages;
  void send(ProtocolMessage message);
  Future<void> close();
}
```

**Production implementation:** `IOWebSocketClient` (uses dart:io)  
**Test implementation:** `MockWebSocketClient` (test/helpers/)

**Benefits:**
- Perfect consistency with HTTP mock pattern
- Direct injection (no factories or globals)
- Type-safe compile-time checking
- Easy to test and maintain

## Connection State Machine

The `Connection` class implements the full Ably connection state machine:

**States:** INITIALIZED → CONNECTING → CONNECTED → DISCONNECTED → SUSPENDED → CLOSING → CLOSED / FAILED

**Responsibilities:**
- WebSocket lifecycle management
- Protocol message handling (CONNECTED, DISCONNECTED, ERROR, etc.)
- Timeout management (connection timeout, retry timeout)
- Token error detection and renewal
- Connection resume with fallback
- Fallback host retry on failure
- Observable state changes

**Key implementation detail:** Connection IS the state machine (not separate classes). This simplification keeps the code maintainable while meeting all spec requirements.

## Fallback Host Strategy

When primary host fails, the client automatically tries fallback hosts:

1. **Primary host:** `realtime.ably.io` (or custom)
2. **Fallback hosts:** `main.a.fallback.ably-realtime.com` through `main.e.fallback.ably-realtime.com`

**Triggering conditions:**
- DNS resolution failure
- Connection timeout
- Connection refused
- Protocol-level 5xx errors

**Implementation:** `HostSelector` class manages fallback logic per REC and RTN17 specs.

## Protocol Messages

Communication between client and server uses binary protocol messages:

```dart
class ProtocolMessage {
  final ProtocolAction action;  // CONNECTED, MESSAGE, ATTACH, etc.
  final ConnectionDetails? connectionDetails;
  final ErrorInfo? error;
  // ... other fields
}
```

**Serialization:** JSON over WebSocket (text frames)  
**Actions:** Enum mapping to wire protocol integers

## Testing Architecture

### Mock Infrastructure

**MockHttpClient** - Simulates HTTP requests
- Handler pattern: `onRequest: (req) => req.respondWith(...)`
- Awaitable pattern: `await mock.awaitRequest()`
- Simulates: DNS errors, connection refused, timeouts, various responses

**MockWebSocketClient** - Simulates WebSocket connections
- Handler pattern: `onConnectionAttempt: (conn) => conn.respondWithSuccess(...)`
- Awaitable pattern: `await mock.awaitConnectionAttempt()`
- Simulates: Connection failures, protocol errors, unexpected disconnects
- UTS-compliant event timeline

### Test Patterns

**Unit tests:** Use mocks to test behavior in isolation  
**Integration tests:** Use real Ably sandbox for end-to-end validation

All tests reference specification IDs (RTN17a, RSC6, etc.) for traceability.

## Key Architectural Decisions

### 1. Merged Connection and State Machine

**Why:** Users interact with `Connection`, which directly manages its own state. No need for separate state machine class that just adds indirection.

### 2. Direct Timer Usage

**Why:** Standard Dart `Timer` is sufficient. No need for custom `TimerManager` abstraction in production code (optional for tests).

### 3. Interface/Implementation Split

**Why:** Enables dependency injection while keeping public API clean. Tests inject mocks via constructors without changing public interface.

### 4. Shared Auth and HTTP Client

**Why:** Realtime client needs HTTP for token renewal. Don't duplicate auth logic. Share implementation between REST and Realtime.

### 5. WebSocket Client Interface

**Why:** Perfect consistency with HTTP mock pattern. Same injection approach for both clients. No factories or globals needed.

## Component Boundaries

**Clear separation:**
- **Interfaces** (lib/src/rest/, lib/src/realtime/) - Public API contracts
- **Implementations** (lib/src/impl/) - Concrete implementations
- **Types** (lib/src/message/, lib/src/error/) - Shared data structures
- **Tests** (test/) - Separate from production code

**Shared between clients:**
- AuthImpl
- AblyHttpClient  
- ClientOptions
- Error types
- Message types

**Client-specific:**
- REST: RestImpl, RestChannelsImpl, RestChannelImpl
- Realtime: RealtimeImpl, Connection, RealtimeChannels

## Dart-Idiomatic Event Pattern

The Ably features specification defines an `EventEmitter` interface (RTE3-RTE6) used by Connection, RealtimeChannel, and other objects. In Dart, we use **Streams** instead, which is the idiomatic Dart approach for observable events.

### Spec EventEmitter vs Dart Streams

| Spec EventEmitter | Dart Equivalent |
|-------------------|-----------------|
| `on(listener)` | `stream.listen(listener)` |
| `on(event, listener)` | `on(event).listen(listener)` |
| `once(listener)` | `stream.first.then(listener)` |
| `once(event, listener)` | `on(event).first.then(listener)` |
| `off(listener)` | `subscription.cancel()` |
| `off()` | Cancel all subscriptions (user responsibility) |

### Implementation Pattern

For any class that emits events (Connection, RealtimeChannel, RealtimePresence):

```dart
class Connection {
  // Private broadcast controller for emitting events
  final _stateChangeController = StreamController<ConnectionStateChange>.broadcast();
  
  // Public stream accessor with optional filtering
  Stream<ConnectionStateChange> on([ConnectionEvent? event]) {
    if (event == null) {
      return _stateChangeController.stream;
    }
    return _stateChangeController.stream.where((change) => change.event == event);
  }
  
  // Internal: emit an event
  void _emitStateChange(ConnectionStateChange change) {
    _stateChangeController.add(change);
  }
  
  // Cleanup
  Future<void> close() async {
    await _stateChangeController.close();
  }
}
```

### Usage Examples

```dart
// Listen to all state changes
final subscription = connection.on().listen((change) {
  print('State changed: ${change.previous} -> ${change.current}');
});

// Listen to specific event
connection.on(ConnectionEvent.connected).listen((change) {
  print('Connected!');
});

// One-time listener
connection.on(ConnectionEvent.connected).first.then((change) {
  print('Connected once!');
});

// Stop listening
subscription.cancel();
```

### Why Streams Instead of EventEmitter

1. **Dart idiom** - Streams are the standard async pattern in Dart
2. **Type safety** - Generic streams provide compile-time type checking
3. **Composability** - Streams work with `async/await`, `StreamBuilder`, etc.
4. **Resource management** - `StreamSubscription.cancel()` is explicit and clear
5. **Framework integration** - Flutter widgets can use `StreamBuilder` directly

### Consistency Requirements

All observable objects must follow this pattern:

| Object | Event Type | Data Type | Method |
|--------|------------|-----------|--------|
| Connection | `ConnectionEvent` | `ConnectionStateChange` | `on([event])` |
| RealtimeChannel | `ChannelEvent` | `ChannelStateChange` | `on([event])` |
| RealtimePresence | `PresenceAction` | `PresenceMessage` | `subscribe([action])` |
| RealtimeChannel (messages) | - | `Message` | `subscribe([name])` |

### State Change Data Classes

Each state change event includes:

```dart
class ConnectionStateChange {
  final ConnectionEvent event;      // The event that occurred
  final ConnectionState current;    // New state
  final ConnectionState previous;   // Previous state  
  final ErrorInfo? reason;          // Error info if applicable
  final int? retryIn;               // Milliseconds until retry (if applicable)
}
```

Channel state changes follow the same pattern with `ChannelEvent` and `ChannelState`.

### Convenience Methods

For common "wait for state" patterns, provide convenience methods:

```dart
/// Calls listener immediately if already in target state,
/// otherwise waits for state transition.
void whenState(
  ConnectionState targetState,
  void Function(ConnectionStateChange) listener,
) {
  if (state == targetState) {
    listener(ConnectionStateChange(...));
    return;
  }
  on().where((c) => c.current == targetState).first.then(listener);
}
```

## Future Architecture Considerations

### Realtime Channels

When implementing realtime channels (attach/detach/subscribe/publish):

- Follow same interface/impl pattern
- Channel has its own state machine (INITIALIZED → ATTACHING → ATTACHED → DETACHING → DETACHED)
- Subscribe returns Stream<Message> (Dart idiomatic)
- Message queueing while channel attaching

### Realtime Presence

When implementing realtime presence:

- RealtimePresence per channel
- Uses protocol messages (PRESENCE action)
- Observable: Stream<PresenceMessage>
- Sync protocol for initial presence set

## Performance Characteristics

**Memory:**
- Connection maintains single WebSocket
- Channels are lazy-created and cached
- Protocol messages parsed on-demand

**CPU:**
- JSON parsing for protocol messages
- State machine transitions are synchronous
- Timer callbacks for retries/timeouts

**Network:**
- WebSocket provides persistent connection
- Automatic reconnection with exponential backoff
- Fallback host retry on failures
