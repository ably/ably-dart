# MockHttpClient - Handler-Based Interface

The `MockHttpClient` provides a flexible testing interface for mocking HTTP requests in the Ably Dart SDK test suite.

## Overview

The MockHttpClient uses a handler-based pattern where callback functions are invoked for each connection attempt or request. This allows tests to respond dynamically based on request details.

## Handler-Based Pattern

### Basic Request Handling

```dart
final mock = MockHttpClient(
  onRequest: (request) {
    if (request.url.path == '/time') {
      request.respondWith(200, {'time': 1234567890000});
    } else if (request.url.path.startsWith('/channels/')) {
      // Access request details
      final json = request.jsonBody;
      request.respondWith(201, {'success': true});
    } else {
      request.respondWith(404, {'error': {'code': 40400}});
    }
  },
);

// Make requests
final response = await mock.get(Uri.parse('https://rest.ably.io/time'));
```

### Connection-Level Control

Use `onConnectionAttempt` to simulate connection failures:

```dart
final mock = MockHttpClient(
  onConnectionAttempt: (connection) {
    if (shouldFail) {
      connection.respondWithRefused();  // Connection refused
      // or connection.respondWithTimeout();
      // or connection.respondWithDnsError();
    } else {
      connection.respondWithSuccess();
    }
  },
  onRequest: (request) {
    request.respondWith(200, {'success': true});
  },
);
```

### Awaitable Pattern

For tests that need to coordinate responses with test state:

```dart
final mock = MockHttpClient();

// Set up listener BEFORE making request
final requestListener = mock.awaitRequest();

// Make request in background
final requestFuture = mock.get(Uri.parse('https://rest.ably.io/test'));

// Wait for request and inspect it
final pendingRequest = await requestListener;
if (pendingRequest.headers.containsKey('Authorization')) {
  pendingRequest.respondWith(200, {'authenticated': true});
} else {
  pendingRequest.respondWith(401, {'error': {'code': 40100}});
}

final response = await requestFuture;
```

## API Reference

### Constructor

```dart
MockHttpClient({
  ConnectionHandler? onConnectionAttempt,
  RequestHandler? onRequest,
})
```

If no handlers are provided, the mock will automatically succeed connections and respond with `200 {}` for all requests.

### PendingConnection

Represents a connection attempt that can be responded to:

**Properties:**
- `host: String` - The hostname being connected to
- `port: int` - The port being connected to
- `tls: bool` - Whether TLS/HTTPS is being used
- `timestamp: DateTime` - When the connection was attempted

**Methods:**
- `respondWithSuccess()` - Connection succeeds
- `respondWithRefused()` - Connection refused error
- `respondWithTimeout()` - Connection timeout
- `respondWithDnsError()` - DNS resolution failure

### PendingRequest

Represents an HTTP request that can be responded to:

**Properties:**
- `url: Uri` - The URL being requested
- `method: String` - HTTP method (GET, POST, etc.)
- `headers: Map<String, String>` - Request headers
- `body: List<int>` - Request body as bytes
- `bodyAsString: String` - Request body as UTF-8 string
- `jsonBody: dynamic` - Request body parsed as JSON
- `timestamp: DateTime` - When the request was made

**Methods:**
- `respondWith(int status, Object body, {Map<String, String>? headers})` - Respond immediately
- `respondWithDelay(Duration delay, int status, Object body, {Map<String, String>? headers})` - Respond after a delay
- `respondWithTimeout()` - Request timeout error

### Awaitable Methods

```dart
Future<PendingConnection> awaitConnectionAttempt({
  Duration timeout = const Duration(seconds: 5),
})

Future<PendingRequest> awaitRequest({
  Duration timeout = const Duration(seconds: 5),
})
```

**Important:** Call these methods BEFORE making the request to set up the awaitable listener.

### Inspection

```dart
List<CapturedRequest> capturedRequests  // All captured requests
List<CapturedRequest> capturedRequestsForHost(String host)
```

### Management

```dart
void reset()      // Clear captured requests
void dispose()    // Clean up resources (call in tearDown)
```

## Examples

See `/Users/paddy/data/worknew/dev/dart-experiments/ably-dart/test/helpers/mock_http_client_example.dart` for comprehensive examples including:

1. Basic handler-based request handling
2. Connection-level control
3. Awaitable pattern for coordinated testing
4. Error simulation (connection refused, DNS errors, timeouts, delays)

Run the examples:
```bash
dart run test/helpers/mock_http_client_example.dart
```

## Testing

Run the test suite:
```bash
dart test test/helpers/mock_http_client_test.dart
```

## Design Rationale

The handler-based interface provides several advantages:

1. **Flexibility**: Responses can be determined dynamically based on request details
2. **Readability**: Request handling logic is co-located with test setup
3. **Maintainability**: Tests are easier to understand and modify
4. **Type Safety**: Strongly-typed interfaces for connections and requests
5. **Coordination**: Awaitable pattern allows tests to coordinate responses with test state
