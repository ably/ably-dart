/// Examples demonstrating the MockHttpClient handler-based interface.
///
/// This file provides examples of how to use the new handler-based
/// configuration pattern for MockHttpClient.

import 'package:http/http.dart' as http;
import 'mock_http_client.dart';

void main() async {
  // Example 1: Basic handler-based request handling
  await example1_BasicHandlerPattern();

  // Example 2: Connection-level control
  await example2_ConnectionControl();

  // Example 3: Awaitable pattern for coordinated testing
  await example3_AwaitablePattern();

  // Example 4: Simulating errors
  await example4_ErrorSimulation();

  // Example 5: Backward compatibility with queue-based pattern
  await example5_BackwardCompatibility();
}

/// Example 1: Basic handler-based request handling
///
/// This is the recommended pattern for most tests.
Future<void> example1_BasicHandlerPattern() async {
  print('Example 1: Basic handler-based request handling\n');

  final mock = MockHttpClient(
    onRequest: (request) {
      print('  Received ${request.method} ${request.url.path}');

      // Route based on URL path
      if (request.url.path == '/time') {
        request.respondWith(200, {'time': 1234567890000});
      } else if (request.url.path.startsWith('/channels/')) {
        // Parse request body
        if (request.body.isNotEmpty) {
          final json = request.jsonBody;
          print('  Request body: $json');
          request.respondWith(201, {'success': true});
        } else {
          request.respondWith(400, {'error': {'code': 40000}});
        }
      } else {
        request.respondWith(404, {'error': {'code': 40400}});
      }
    },
  );

  // Make some requests
  final timeResponse = await mock.get(Uri.parse('https://rest.ably.io/time'));
  print('  Time response status: ${timeResponse.statusCode}\n');

  final publishResponse = await mock.post(
    Uri.parse('https://rest.ably.io/channels/test/messages'),
    body: '{"name":"event","data":"payload"}',
  );
  print('  Publish response status: ${publishResponse.statusCode}\n');

  mock.dispose();
}

/// Example 2: Connection-level control
///
/// Use this when you need to simulate connection failures before
/// any HTTP request can be made.
Future<void> example2_ConnectionControl() async {
  print('Example 2: Connection-level control\n');

  var attemptCount = 0;

  final mock = MockHttpClient(
    onConnectionAttempt: (connection) {
      attemptCount++;
      print('  Connection attempt $attemptCount to ${connection.host}');

      // Simulate first connection failing
      if (attemptCount == 1) {
        print('  Refusing first connection');
        connection.respondWithRefused();
      } else {
        print('  Allowing connection');
        connection.respondWithSuccess();
      }
    },
    onRequest: (request) {
      print('  Request succeeded: ${request.method} ${request.url.path}');
      request.respondWith(200, {'success': true});
    },
  );

  // First request fails at connection level
  try {
    await mock.get(Uri.parse('https://rest.ably.io/test'));
  } catch (e) {
    print('  First request failed: $e');
  }

  // Second request succeeds
  final response = await mock.get(Uri.parse('https://rest.ably.io/test'));
  print('  Second request status: ${response.statusCode}\n');

  mock.dispose();
}

/// Example 3: Awaitable pattern for coordinated testing
///
/// Use this when test code needs to coordinate responses with test state,
/// or when responses need to be provided at specific points in the test.
Future<void> example3_AwaitablePattern() async {
  print('Example 3: Awaitable pattern for coordinated testing\n');

  final mock = MockHttpClient();

  // Set up awaitable mode by calling awaitRequest FIRST
  print('  Setting up request listener...');
  final requestListener = mock.awaitRequest();

  // Start request in background
  print('  Starting background request...');
  final requestFuture = mock.get(Uri.parse('https://rest.ably.io/test'));

  // Now wait for and respond to the request
  print('  Waiting for request...');
  final pendingRequest = await requestListener;
  print('  Got request: ${pendingRequest.method} ${pendingRequest.url.path}');

  // Check request details before responding
  if (pendingRequest.headers.containsKey('Authorization')) {
    print('  Request has auth header');
    pendingRequest.respondWith(200, {'authenticated': true});
  } else {
    pendingRequest.respondWith(401, {'error': {'code': 40100}});
  }

  final response = await requestFuture;
  print('  Response status: ${response.statusCode}\n');

  mock.dispose();
}

/// Example 4: Simulating errors
///
/// Demonstrates various error simulation capabilities.
Future<void> example4_ErrorSimulation() async {
  print('Example 4: Simulating errors\n');

  // Connection refused
  print('  4a. Connection refused:');
  final mock1 = MockHttpClient(
    onConnectionAttempt: (connection) {
      connection.respondWithRefused();
    },
  );

  try {
    await mock1.get(Uri.parse('https://rest.ably.io/test'));
  } catch (e) {
    print('    Caught: ${e.runtimeType}');
  }
  mock1.dispose();

  // DNS error
  print('\n  4b. DNS error:');
  final mock2 = MockHttpClient(
    onConnectionAttempt: (connection) {
      connection.respondWithDnsError();
    },
  );

  try {
    await mock2.get(Uri.parse('https://rest.ably.io/test'));
  } catch (e) {
    print('    Caught: ${e.runtimeType}');
  }
  mock2.dispose();

  // Request timeout
  print('\n  4c. Request timeout:');
  final mock3 = MockHttpClient(
    onRequest: (request) {
      request.respondWithTimeout();
    },
  );

  try {
    await mock3.get(Uri.parse('https://rest.ably.io/test'));
  } catch (e) {
    print('    Caught: ${e.runtimeType}');
  }
  mock3.dispose();

  // Delayed response
  print('\n  4d. Delayed response:');
  final mock4 = MockHttpClient(
    onRequest: (request) {
      print('    Responding with 100ms delay...');
      request.respondWithDelay(
        Duration(milliseconds: 100),
        200,
        {'delayed': true},
      );
    },
  );

  final stopwatch = Stopwatch()..start();
  final response = await mock4.get(Uri.parse('https://rest.ably.io/test'));
  stopwatch.stop();
  print('    Response received after ${stopwatch.elapsedMilliseconds}ms');
  print('    Status: ${response.statusCode}\n');
  mock4.dispose();
}

/// Example 5: Backward compatibility with queue-based pattern
///
/// The old queue-based pattern is still supported (but deprecated).
Future<void> example5_BackwardCompatibility() async {
  print('Example 5: Backward compatibility with queue-based pattern\n');

  final mock = MockHttpClient();

  // Old pattern: queue responses in advance
  print('  Queueing responses...');
  mock.queueResponse(200, {'first': true});
  mock.queueResponse(201, {'second': true});
  mock.queueResponseForHost('fallback.ably.io', 200, {'fallback': true});

  // Requests consume queued responses in order
  final response1 = await mock.get(Uri.parse('https://rest.ably.io/test1'));
  print('  First response status: ${response1.statusCode}');

  final response2 = await mock.get(Uri.parse('https://rest.ably.io/test2'));
  print('  Second response status: ${response2.statusCode}');

  final response3 = await mock.get(Uri.parse('https://fallback.ably.io/test'));
  print('  Fallback response status: ${response3.statusCode}');

  // Inspect captured requests
  print('  Captured ${mock.capturedRequests.length} requests');
  for (final req in mock.capturedRequests) {
    print('    - ${req.method} ${req.url}');
  }
  print('');

  mock.dispose();
}
