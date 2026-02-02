# ably-dart

Pure Dart implementation of the [Ably](https://ably.com) realtime messaging SDK.

## Overview

This package provides a pure Dart client for the Ably realtime messaging platform. It implements the [Ably client library specification](https://sdk.ably.com/builds/ably/specification/main/features/) and serves as the foundation for [ably-flutter](https://github.com/ably/ably-flutter).

**Key Features:**
- ✅ REST API (time, stats, request, batch publish)
- ✅ Realtime connection management with automatic fallback
- ✅ Authentication (API keys, token auth, callbacks, authUrl)
- ✅ Channel operations (publish, history)
- ✅ Presence queries
- ✅ Pagination support
- ⏳ Realtime channels (in development)

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  ably_dart: ^0.1.0  # Check for latest version
```

## Quick Start

### REST Client

```dart
import 'package:ably_dart/ably_dart.dart';

// Using API key
final client = Rest(
  options: ClientOptions.fromKey('your-api-key'),
);

// Get server time
final serverTime = await client.time();
print('Server time: $serverTime');

// Publish to a channel
final channel = client.channels.get('my-channel');
await channel.publish(name: 'greeting', data: 'Hello, Ably!');

// Close when done
await client.close();
```

### Realtime Client

```dart
import 'package:ably_dart/ably_dart.dart';

// Create client
final client = Realtime(
  options: ClientOptions.fromKey('your-api-key'),
);

// Listen for connection state changes
client.connection.on().listen((stateChange) {
  print('Connection state: ${stateChange.current}');
});

// Connect
await client.connect();

// Close when done
await client.close();
```

## Architecture

This SDK follows a clean separation between interfaces and implementations:

```
lib/src/
├── rest/              # REST client interface
├── realtime/          # Realtime client interface + state management
├── impl/              # Concrete implementations
│   ├── rest_impl.dart
│   ├── realtime_impl.dart
│   ├── auth_impl.dart        # Shared authentication
│   └── http/                 # Shared HTTP client
├── auth/              # Authentication types
├── channels/          # Channel interfaces
├── message/           # Message types
└── error/             # Error types
```

**Key Design Decisions:**
- **Interface/Implementation Split:** Enables dependency injection for testing
- **Shared Infrastructure:** REST and Realtime share `AuthImpl` and `AblyHttpClient`
- **Dependency Injection:** Test doubles can be injected via constructors

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed architecture documentation.

## Testing

### Running Tests

```bash
# All tests
dart test

# Specific test file
dart test test/unit/realtime/connection/fallback_hosts_test.dart

# Integration tests (requires Ably sandbox access)
dart test test/integration/

# With detailed stack traces
dart test --chain-stack-traces
```

### Test Infrastructure

The SDK includes comprehensive mock clients for testing:

**MockHttpClient** - For REST testing
```dart
final mockHttp = MockHttpClient(
  onRequest: (req) {
    req.respondWith(200, {'result': 'ok'});
  },
);

final client = Rest(
  options: ClientOptions.fromKey('test.key:secret'),
  httpClient: mockHttp,
);
```

**MockWebSocketClient** - For Realtime testing
```dart
final mockWs = MockWebSocketClient(
  onConnectionAttempt: (conn) {
    conn.respondWithSuccess(
      ProtocolMessageHelpers.connected(
        connectionId: 'test-id',
        connectionKey: 'test-key',
      ),
    );
  },
);

final client = Realtime.forTesting(
  options: ClientOptions.fromKey('test.key:secret'),
  webSocketClient: mockWs,
);
```

See [test/helpers/MOCK_HTTP_CLIENT.md](test/helpers/MOCK_HTTP_CLIENT.md) for detailed documentation.

## Specification Compliance

This SDK implements the [Universal Test Specification (UTS)](https://github.com/ably/ably-common/tree/main/test-resources) for Ably client libraries.

**Current Test Status:**
- 310+ tests passing
- 19 tests skipped (awaiting features)
- ~13 tests failing (under investigation)

All tests reference Ably specification points (e.g., `RTN17a`, `RSC6`, `REC2c1`) making it easy to trace implementation to requirements.

See [TEST_IMPLEMENTATION_STATUS.md](TEST_IMPLEMENTATION_STATUS.md) for detailed coverage.

## Implementation Status

### ✅ Complete

- **REST Client** - Full API coverage (time, stats, request, batch publish)
- **Authentication** - API key, token auth, callbacks, authUrl
- **Realtime Connection** - Full state machine with fallback hosts
- **Fallback Hosts** - Automatic fallback on connection failures (REC1, REC2, REC3, RTN17)
- **Token Renewal** - Automatic token renewal on expiry
- **Heartbeat & Updates** - Connection health monitoring (RTN23, RTN24)
- **State Management** - Observable state changes (RTN26)

### ⏳ In Development

- **Realtime Channels** - Attach, detach, subscribe, publish
- **Realtime Presence** - Presence set operations
- **Message Queueing** - Offline message queueing

See [REALTIME_IMPLEMENTATION_COMPLETE.md](REALTIME_IMPLEMENTATION_COMPLETE.md) for detailed status.

## Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture and design decisions
- **[REALTIME_IMPLEMENTATION_COMPLETE.md](REALTIME_IMPLEMENTATION_COMPLETE.md)** - Implementation status
- **[TEST_IMPLEMENTATION_STATUS.md](TEST_IMPLEMENTATION_STATUS.md)** - Test coverage details
- **[test/helpers/MOCK_HTTP_CLIENT.md](test/helpers/MOCK_HTTP_CLIENT.md)** - Mock infrastructure reference
- **[Ably Specification](https://sdk.ably.com/builds/ably/specification/main/features/)** - Official spec

## Contributing

When contributing:

1. **Reference specs** - All tests must include specification IDs (e.g., `RTN17a`)
2. **Follow patterns** - Use existing interface/implementation patterns
3. **Test thoroughly** - Unit tests with mocks, integration tests with real Ably
4. **Document decisions** - Update relevant .md files for architectural changes

See [.claude/CLAUDE.md](.claude/CLAUDE.md) for detailed development guidelines.

## License

Copyright (c) 2024 Ably Real-time Ltd, Licensed under the Apache License, Version 2.0.
