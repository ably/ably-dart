import 'protocol_message.dart';

/// Abstract WebSocket client interface.
///
/// Provides abstraction between realtime client and WebSocket implementation.
/// Production uses [IOWebSocketClient], tests use [MockWebSocketClient].
///
/// This follows the same pattern as HTTP mock injection for consistency.
abstract class WebSocketClient {
  /// Connects to the specified URL.
  ///
  /// Returns a [WebSocketConnection] that can be used to send and receive
  /// protocol messages.
  Future<WebSocketConnection> connect(Uri url);
}

/// Abstract WebSocket connection interface.
///
/// Represents an established WebSocket connection with methods for
/// sending and receiving protocol messages.
abstract class WebSocketConnection {
  /// Stream of incoming protocol messages from server.
  Stream<ProtocolMessage> get messages;

  /// Sends a protocol message to the server.
  void send(ProtocolMessage message);

  /// Closes the connection.
  Future<void> close();
}
