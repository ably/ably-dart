# ably-dart

Pure Dart implementation of the [Ably](https://ably.com) realtime messaging SDK.

## Overview

This package provides a pure Dart client for the Ably realtime messaging platform. It implements the [Ably client library specification](https://sdk.ably.com/builds/ably/specification/main/features/) and serves as the foundation for [ably-flutter](https://github.com/ably/ably-flutter).

**Key Features:**
- REST API (time, stats, request, batch publish)
- Realtime connection management with automatic fallback
- Authentication (API keys, token auth, JWT, callbacks, authUrl)
- In-band reauthorization (RTC8)
- Automatic token renewal on expiry
- Channel operations (attach, detach, subscribe, publish, history)
- Presence queries
- Pagination support

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
│   ├── auth_impl.dart         # Shared authentication
│   ├── realtime_auth.dart     # Realtime auth wrapper (RTC8)
│   └── http/                  # Shared HTTP client
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
- 750 unit tests, all passing
- 13 integration tests (Ably sandbox), all passing
- 763 total, 0 failures

All tests reference Ably specification points (e.g., `RTN17a`, `RSC6`, `REC2c1`) making it easy to trace implementation to requirements.

See [test/completion-status.md](test/completion-status.md) for detailed spec coverage.

## Implementation Status

### Complete

- **REST Client** - Full API coverage (time, stats, request, batch publish)
- **Authentication** - API key, token auth, JWT, callbacks, authUrl (RSA1-RSA16)
- **In-band Reauthorization** - `auth.authorize()` on connected client (RTC8)
- **Token Renewal** - Automatic renewal on expiry, correct token error scoping (RSC10, RSC10b)
- **Token Request Signing** - `createTokenRequest()` with server-deferred defaults (RSA5, RSA6, RSA9)
- **Realtime Connection** - Full state machine with fallback hosts (RTN14, RTN15, RTN17)
- **Realtime Channels** - Attach, detach, subscribe, publish (RTL4-RTL8, RTL13, RTL14)
- **Heartbeat & Updates** - Connection health monitoring (RTN23, RTN24)
- **State Management** - Observable state changes (RTN26)
- **REST Presence** - Get and history queries (RSP1-RSP5)
- **Pagination** - Full paginated result support (TG1-TG7)

### Not Implemented

- **Server-Initiated Reauth** - RTN22 (UTS spec exists)
- **Realtime Presence** - Enter/leave/update operations (RTP)
- **Message Encryption** - RSL5, RSE1-RSE2
- **Push Notifications** - RSH1-RSH8
- **Msgpack** - Binary protocol not supported; JSON only

## Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture and design decisions
- **[test/completion-status.md](test/completion-status.md)** - Spec-by-spec test coverage matrix
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
