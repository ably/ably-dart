import 'dart:async';
import 'dart:io';

import 'package:ably_dart/src/error/error_info.dart';
import 'package:ably_dart/src/realtime/protocol_message.dart';
import 'package:ably_dart/src/realtime/websocket_client.dart';

/// Callback for handling connection attempts in the mock WebSocket client.
typedef ConnectionAttemptHandler = void Function(
  PendingWebSocketConnection connection,
);

/// Callback for handling messages from client.
typedef MessageFromClientHandler = void Function(ProtocolMessage message);

/// Mock WebSocket client that implements the UTS specification pattern.
///
/// This mock supports both handler-based and awaitable patterns for maximum
/// test flexibility. It provides complete control over connection outcomes
/// and message flow.
///
/// Example with handlers:
/// ```dart
/// final mock = MockWebSocketClient(
///   onConnectionAttempt: (conn) {
///     if (shouldFail) {
///       conn.respondWithRefused();
///     } else {
///       conn.respondWithSuccess(CONNECTED_MESSAGE);
///     }
///   },
/// );
/// ```
///
/// Example with await pattern:
/// ```dart
/// final mock = MockWebSocketClient();
/// final connFuture = mock.awaitConnectionAttempt();
///
/// // Trigger connection in background
/// client.connect();
///
/// // Wait for and respond to connection
/// final conn = await connFuture;
/// expect(conn.url.host, 'realtime.ably.io');
/// conn.respondWithSuccess(CONNECTED_MESSAGE);
/// ```
class MockWebSocketClient implements WebSocketClient {
  MockWebSocketClient({
    this.onConnectionAttempt,
    this.onMessageFromClient,
  });

  /// Handler called for each connection attempt.
  final ConnectionAttemptHandler? onConnectionAttempt;

  /// Handler called for each message from client.
  final MessageFromClientHandler? onMessageFromClient;

  /// Event timeline (UTS requirement) - chronological sequence of all events.
  final List<MockEvent> events = [];

  /// The currently active connection (null if not connected).
  MockWebSocketConnection? activeConnection;

  /// Streams for awaitable patterns.
  final StreamController<PendingWebSocketConnection> _connectionAttempts =
      StreamController<PendingWebSocketConnection>.broadcast();
  final StreamController<ProtocolMessage> _messagesFromClient =
      StreamController<ProtocolMessage>.broadcast();
  final StreamController<void> _closeRequests =
      StreamController<void>.broadcast();

  /// Awaits the next connection attempt (UTS pattern).
  ///
  /// This must be called BEFORE initiating the connection to ensure
  /// the listener is set up.
  Future<PendingWebSocketConnection> awaitConnectionAttempt({
    Duration timeout = const Duration(seconds: 5),
  }) {
    return _connectionAttempts.stream.first.timeout(timeout);
  }

  /// Awaits the next message from client (UTS pattern).
  Future<ProtocolMessage> awaitNextMessageFromClient({
    Duration timeout = const Duration(seconds: 5),
  }) {
    return _messagesFromClient.stream.first.timeout(timeout);
  }

  /// Awaits close request from client (UTS pattern).
  Future<void> awaitCloseRequest({
    Duration timeout = const Duration(seconds: 5),
  }) {
    return _closeRequests.stream.first.timeout(timeout);
  }

  /// Initiates a WebSocket connection.
  ///
  /// The returned future completes when the test code responds via
  /// PendingWebSocketConnection methods.
  @override
  Future<MockWebSocketConnection> connect(Uri url) async {
    final pendingConnection = PendingWebSocketConnection._(
      url: url,
      protocol: 'json', // Default protocol
      timestamp: DateTime.now(),
      onMessageFromClient: onMessageFromClient,
    );

    // Record event
    events.add(MockEvent(
      type: MockEventType.connectionAttempt,
      timestamp: DateTime.now(),
      data: pendingConnection,
    ));

    // Emit for awaitable pattern
    if (!_connectionAttempts.isClosed) {
      _connectionAttempts.add(pendingConnection);
    }

    // Call handler if provided
    if (onConnectionAttempt != null) {
      onConnectionAttempt!(pendingConnection);
    }

    // Wait for test to respond
    final connection = await pendingConnection._completer.future;

    // Forward messages from client to stream
    connection._messagesFromClient.stream.listen((msg) {
      if (!_messagesFromClient.isClosed) {
        _messagesFromClient.add(msg);
      }
    });

    // Forward close requests
    connection._closeRequests.stream.listen((_) {
      if (!_closeRequests.isClosed) {
        _closeRequests.add(null);
      }
    });

    // Store as active connection
    activeConnection = connection;

    // Clear active connection when closed
    connection._closeRequests.stream.listen((_) {
      if (activeConnection == connection) {
        activeConnection = null;
      }
    });

    return connection;
  }

  /// Disposes resources.
  void dispose() {
    _connectionAttempts.close();
    _messagesFromClient.close();
    _closeRequests.close();
  }
}

/// Represents a pending WebSocket connection attempt (UTS pattern).
///
/// Tests use this to inspect the connection URL and parameters before
/// deciding how to respond (success, refused, timeout, etc).
class PendingWebSocketConnection {
  PendingWebSocketConnection._({
    required this.url,
    required this.protocol,
    required this.timestamp,
    this.onMessageFromClient,
  });

  /// The URL being connected to.
  final Uri url;

  /// The WebSocket protocol (e.g., 'application/json').
  final String protocol;

  /// When the connection was attempted.
  final DateTime timestamp;

  /// Optional handler for messages from client.
  final MessageFromClientHandler? onMessageFromClient;

  final Completer<MockWebSocketConnection> _completer = Completer();

  /// Responds with successful connection and sends CONNECTED message.
  void respondWithSuccess(ProtocolMessage connectedMessage) {
    if (_completer.isCompleted) return;

    final mockConnection = MockWebSocketConnection._(
      onMessage: connectedMessage,
      onMessageFromClient: onMessageFromClient,
    );
    _completer.complete(mockConnection);
  }

  /// Responds with connection refused error.
  void respondWithRefused() {
    if (_completer.isCompleted) return;
    _completer.completeError(
      const SocketException('Connection refused'),
    );
  }

  /// Responds with connection timeout.
  void respondWithTimeout() {
    if (_completer.isCompleted) return;
    _completer.completeError(
      TimeoutException('Connection timed out'),
    );
  }

  /// Responds with DNS resolution error.
  void respondWithDnsError() {
    if (_completer.isCompleted) return;
    _completer.completeError(
      SocketException('Failed to resolve hostname: ${url.host}'),
    );
  }

  /// WebSocket connects successfully but server sends ERROR message.
  ///
  /// If [thenClose] is true, the connection will be closed after sending
  /// the error message.
  void respondWithError(
    ProtocolMessage errorMessage, {
    bool thenClose = true,
  }) {
    if (_completer.isCompleted) return;

    final mockConnection = MockWebSocketConnection._(
      onMessage: errorMessage,
      autoClose: thenClose,
      onMessageFromClient: onMessageFromClient,
    );
    _completer.complete(mockConnection);
  }
}

/// Mock WebSocket connection for an established connection.
///
/// This represents a successfully opened WebSocket connection. Tests can
/// inject messages from server and inspect messages from client.
class MockWebSocketConnection implements WebSocketConnection {
  MockWebSocketConnection._({
    ProtocolMessage? onMessage,
    bool autoClose = false,
    this.onMessageFromClient,
  }) {
    if (onMessage != null) {
      // Use a small delay to ensure listeners are attached
      Future.delayed(Duration(milliseconds: 10), () {
        if (!_closed) {
          _messages.add(onMessage);
          if (autoClose) {
            close();
          }
        }
      });
    }
  }

  /// Handler for messages from client.
  final MessageFromClientHandler? onMessageFromClient;

  /// Stream of incoming messages (server → client).
  final StreamController<ProtocolMessage> _messages =
      StreamController.broadcast();

  /// Stream of outgoing messages (client → server).
  final StreamController<ProtocolMessage> _messagesFromClient =
      StreamController.broadcast();

  /// Stream of close requests from client.
  final StreamController<void> _closeRequests = StreamController.broadcast();

  /// All messages sent by client.
  final List<ProtocolMessage> sentMessages = [];

  bool _closed = false;

  /// Stream of messages from server to client.
  @override
  Stream<ProtocolMessage> get messages => _messages.stream;

  /// Sends a message from client to server.
  @override
  void send(ProtocolMessage message) {
    if (_closed) throw StateError('Connection closed');
    sentMessages.add(message);
    _messagesFromClient.add(message);
    onMessageFromClient?.call(message);
  }

  /// Test helper: Inject message from server to client.
  void sendToClient(ProtocolMessage message) {
    if (!_closed) {
      _messages.add(message);
    }
  }

  /// Test helper: Simulate unexpected disconnect.
  Future<void> simulateDisconnect([ErrorInfo? error]) async {
    if (_closed) return;
    _closed = true;
    if (error != null) {
      _messages.addError(error);
    }
    await _messages.close();
    await _messagesFromClient.close();
    await _closeRequests.close();
  }

  /// Closes the connection.
  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _closeRequests.add(null);
    await _messages.close();
    await _messagesFromClient.close();
    await _closeRequests.close();
  }

  /// Whether the connection is closed.
  bool get isClosed => _closed;
}

/// Event types for UTS event timeline.
enum MockEventType {
  connectionAttempt,
  connectionSuccess,
  connectionFailure,
  messageFromClient,
  messageToClient,
  disconnect,
  closeRequest,
}

/// Event record for UTS event timeline.
///
/// Provides chronological tracking of all mock events for debugging.
class MockEvent {
  MockEvent({
    required this.type,
    required this.timestamp,
    this.data,
  });

  final MockEventType type;
  final DateTime timestamp;
  final Object? data;

  @override
  String toString() => 'MockEvent('
      'type: $type, '
      'timestamp: $timestamp, '
      'data: $data'
      ')';
}
