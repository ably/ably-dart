# Ably Dart SDK - Claude Context

## Project Overview

This is the pure Dart implementation of the Ably realtime messaging SDK. It implements the [Ably client library specification](https://sdk.ably.com/builds/ably/specification/main/features/).

**Key Characteristics:**
- Pure Dart (no platform dependencies)
- Used as dependency by ably-flutter
- UTS (Universal Test Specification) compliant
- Follows REST/Realtime separation pattern from other Ably SDKs

## Architecture Principles

### 1. Interface/Implementation Pattern

Both REST and Realtime clients use a consistent pattern:

```
lib/src/
├── rest/rest.dart              # Abstract interface
├── realtime/realtime.dart      # Abstract interface
└── impl/
    ├── rest_impl.dart          # Concrete implementation
    └── realtime_impl.dart      # Concrete implementation
```

**Why:** Enables dependency injection for testing while keeping public API clean.

### 2. Dependency Injection for Testing

**REST Pattern:**
```dart
// Production
final client = Rest(options: ClientOptions.fromKey(apiKey));

// Testing
final mockHttp = MockHttpClient(...);
final client = Rest(
  options: ClientOptions.fromKey(apiKey),
  httpClient: mockHttp,  // Inject mock
);
```

**Realtime Pattern:**
```dart
// Production
final client = Realtime(options: ClientOptions.fromKey(apiKey));

// Testing (using @visibleForTesting factory)
final mockWs = MockWebSocketClient(...);
final client = Realtime.forTesting(
  options: ClientOptions.fromKey(apiKey),
  webSocketClient: mockWs,  // Inject mock
  httpClient: mockHttp,      // Optional
  timerManager: mockTimer,   // Optional
);
```

**Important:** Realtime has additional `forTesting()` factory because it needs more complex dependency injection (WebSocket, timers). REST doesn't need this since HTTP client injection suffices.

### 3. Shared Infrastructure

**Both clients share:**
- `AuthImpl` (lib/src/impl/auth_impl.dart) - Authentication logic
- `AblyHttpClient` (lib/src/impl/http/http_client.dart) - HTTP operations
- `ClientOptions` (lib/src/auth/client_options.dart) - Configuration

**Why:** Realtime client uses HTTP for initial authentication and token renewal.

## Design Documentation

**Primary references (read these first):**
1. **ARCHITECTURE.md** - Current system architecture and design decisions
2. **REALTIME_IMPLEMENTATION_COMPLETE.md** - What was built and why
3. **TEST_IMPLEMENTATION_STATUS.md** - Test coverage and status

## Test Specification System

### UTS Compliance

Tests follow the **Universal Test Specification** pattern:

1. **Test specs live in:** `../uts/test/` (parent directory)
2. **Test implementations live in:** `test/` (this repo)
3. **Spec IDs are mandatory:** Every test must reference spec points (RTN17a, RSC6, etc.)

### Test Naming Convention

```dart
group('RTN17 - Fallback host behavior', () {
  test('RTN17a - Falls back on DNS failure', () { ... });
  test('RTN17b - Falls back on connection refused', () { ... });
});
```

**Critical:** Always include spec IDs in test group/test names. This makes it trivial to:
- Find tests for any spec point
- Verify coverage
- Trace implementation to requirements

### Mock Infrastructure

**Two mock clients available:**

1. **MockHttpClient** (`test/helpers/mock_http_client.dart`)
   - Dual-mode: Handler callbacks OR awaitable pattern
   - Simulates: DNS errors, connection refused, timeouts, various HTTP responses
   - Captures: All requests for assertion

2. **MockWebSocketClient** (`test/helpers/mock_websocket_client.dart`)
   - Dual-mode: Handler callbacks OR awaitable pattern
   - Simulates: Connection failures, protocol errors, unexpected disconnects
   - Captures: All messages for assertion
   - UTS-compliant event timeline

**Reference:** See `test/helpers/MOCK_HTTP_CLIENT.md` for detailed usage.

## Current Implementation Status

### ✅ Complete and Production-Ready

**REST Client:**
- All core APIs (time, stats, request, batchPublish)
- Authentication (API key, token auth, callbacks, authUrl)
- Pagination
- Fallback hosts
- Channel operations (publish, history)
- Presence queries
- **Test Status:** 310+ tests passing

**Realtime Connection:**
- Full connection state machine (8 states)
- Protocol message handling
- Fallback hosts on connection failure
- Token renewal
- Connection resume
- Heartbeat (RTN23)
- Update events (RTN24)
- State change listeners (RTN26)
- **Test Status:** 4/4 integration tests passing, unit tests mostly passing

### ⏳ Incomplete / Work in Progress

**Realtime Channels:**
- Basic structure exists (`lib/src/realtime/realtime_channel.dart`)
- **Not yet implemented:** Attach, detach, subscribe, publish, presence
- **Status:** Stub implementation marked "kept for future use"

**Known Test Issues:**
- 19 tests skipped (awaiting features)
- ~13 tests failing (under investigation)
- 1 compilation error in test infrastructure (mock_http_client_test.dart:135)

## Common Pitfalls and Gotchas

### 1. Don't Change the Interface/Implementation Pattern

**Wrong:**
```dart
// Making Realtime concrete again
class Realtime {
  Realtime({required ClientOptions options}) { ... }
}
```

**Right:**
```dart
// Keep abstract interface with factory
abstract class Realtime {
  factory Realtime({ClientOptions? options, String? key}) {
    return RealtimeImpl(options: resolvedOptions);
  }
}
```

### 2. Always Use Realtime.forTesting() in Tests

**Wrong:**
```dart
test('connection test', () {
  final client = Realtime(options: options);  // Can't inject mocks!
});
```

**Right:**
```dart
test('connection test', () {
  final mockWs = MockWebSocketClient(...);
  final client = Realtime.forTesting(
    options: options,
    webSocketClient: mockWs,
  );
});
```

### 3. Don't Add Public Test Dependencies

**Wrong:**
```dart
// Adding test dependencies to public constructor
abstract class Realtime {
  factory Realtime({
    required ClientOptions options,
    WebSocketClient? webSocketClient,  // ❌ Don't expose in public API
  });
}
```

**Right:**
```dart
// Use @visibleForTesting factory
abstract class Realtime {
  factory Realtime({required ClientOptions options});
  
  @visibleForTesting
  factory Realtime.forTesting({
    required ClientOptions options,
    WebSocketClient? webSocketClient,  // ✅ Only in test factory
  });
}
```

### 4. Spec References Are Mandatory

**Wrong:**
```dart
test('connection should reconnect', () { ... });  // ❌ No spec ID
```

**Right:**
```dart
test('RTN15b - Connection resumes after DISCONNECTED', () { ... });  // ✅
```

### 5. File Structure Matters

**Wrong locations:**
- ❌ `lib/src/client/rest.dart` (old location)
- ❌ `lib/src/rest_impl.dart` (implementation not in impl/)

**Right locations:**
- ✅ `lib/src/rest/rest.dart` (interface in domain folder)
- ✅ `lib/src/impl/rest_impl.dart` (implementation in impl/)

## Key Files Quick Reference

| What | Where |
|------|-------|
| REST interface | `lib/src/rest/rest.dart` |
| REST implementation | `lib/src/impl/rest_impl.dart` |
| Realtime interface | `lib/src/realtime/realtime.dart` |
| Realtime implementation | `lib/src/impl/realtime_impl.dart` |
| Connection state machine | `lib/src/realtime/connection.dart` |
| Auth (shared) | `lib/src/impl/auth_impl.dart` |
| HTTP client (shared) | `lib/src/impl/http/http_client.dart` |
| WebSocket interface | `lib/src/realtime/websocket_client.dart` |
| WebSocket production impl | `lib/src/realtime/io_websocket_client.dart` |
| Mock HTTP client | `test/helpers/mock_http_client.dart` |
| Mock WebSocket client | `test/helpers/mock_websocket_client.dart` |

## Development Workflow

### Running Tests

```bash
# All tests
dart test

# Specific test file
dart test test/unit/realtime/connection/fallback_hosts_test.dart

# With stack traces (helpful for debugging)
dart test --chain-stack-traces

# Integration tests only (require Ably sandbox)
dart test test/integration/
```

### Adding New Tests

1. Check if spec exists in `../uts/test/`
2. If not, create spec following write-test-spec.md guidelines
3. Implement test in `test/` matching spec structure
4. Use spec IDs in test names
5. Use mock clients for unit tests
6. Use real Ably sandbox for integration tests

### Fixing Failing Tests

**Current approach:**
1. Run failing test with `--chain-stack-traces`
2. Categorize failure:
   - Test infrastructure bug? Fix mock helpers
   - Test setup issue? Fix test code
   - State machine bug? Fix Connection logic
   - Implementation bug? Fix specific method
3. Add regression test if needed
4. Don't change architecture to fix tests

## What to Preserve When Making Changes

### ✅ Always Maintain

1. **Interface/implementation separation** - Don't merge them back
2. **Dependency injection pattern** - Required for testing
3. **Spec ID references in tests** - Makes specs traceable
4. **Mock client dual-mode API** - Both handlers and awaitables
5. **Shared infrastructure** (AuthImpl, AblyHttpClient) - Don't duplicate

### ⚠️ Think Carefully Before Changing

1. **Directory structure** - Other SDKs may follow this pattern
2. **Test naming conventions** - Consistency across Ably SDKs
3. **Public API surface** - Must match ably-flutter expectations
4. **forTesting() pattern** - Industry standard for Dart testing

### 🔄 Safe to Evolve

1. **Internal implementation details** - Connection state machine internals
2. **Test helpers** - Add new methods to mocks as needed
3. **Error handling** - Improve error messages and paths
4. **Performance optimizations** - Internal algorithms

## Resources

- **Ably Spec:** https://sdk.ably.com/builds/ably/specification/main/features/
- **Architecture:** See ARCHITECTURE.md
- **UTS Tests:** `../uts/test/` (parent directory)
- **Test Writing Guide:** `../.claude/skills/write-test-spec.md`
- **Current Status:** See REALTIME_IMPLEMENTATION_COMPLETE.md

## Questions to Ask Yourself

Before making changes, ask:

1. **Does this change the public API?** → Check if ably-flutter depends on current signature
2. **Does this break dependency injection?** → Tests must be able to inject mocks
3. **Does this maintain spec correspondence?** → Test names must include spec IDs
4. **Does this follow the interface/impl pattern?** → Keep separation consistent
5. **Have I updated relevant documentation?** → Update status docs if implementation changes

## Getting Help

If you're unsure about:
- **Architecture decisions:** Read REALTIME_DESIGN_V2.md and WEBSOCKET_MOCK_DESIGN.md
- **Test patterns:** Check existing tests in `test/unit/` and read test/helpers/MOCK_HTTP_CLIENT.md
- **Spec interpretation:** Refer to https://sdk.ably.com/builds/ably/specification/main/features/
- **Implementation status:** Check REALTIME_IMPLEMENTATION_COMPLETE.md and TEST_IMPLEMENTATION_STATUS.md
