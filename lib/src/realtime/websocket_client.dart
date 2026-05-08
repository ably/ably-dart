import 'protocol_message.dart';

/// Listener interface for WebSocket events.
///
/// Passed to [WebSocketClient.connect] to receive all connection events.
/// The listener is attached before the connection completes, ensuring
/// no events are missed.
abstract class WebSocketListener {
  /// Called when a protocol message is received from the server.
  void onMessage(ProtocolMessage message);

  /// Called when an error occurs on the connection.
  void onError(Object error);

  /// Called when the connection is closed.
  ///
  /// [closeCode] and [closeReason] are provided if the server sent them.
  void onClose({int? closeCode, String? closeReason});
}

/// Abstract WebSocket client interface.
///
/// Provides abstraction between realtime client and WebSocket implementation.
/// Production uses [IOWebSocketClient], tests use [MockWebSocketClient].
///
/// This follows the same pattern as HTTP mock injection for consistency.
abstract class WebSocketClient {
  /// Connects to the specified URL.
  ///
  /// The [listener] is attached before the connection completes, ensuring
  /// no events are missed. Returns a [WebSocketConnection] that can be used
  /// to send messages and close the connection.
  ///
  /// When [useBinaryProtocol] is true, the connection sends and receives
  /// MessagePack-encoded binary frames instead of JSON text frames.
  Future<WebSocketConnection> connect(
    Uri url,
    WebSocketListener listener, {
    bool useBinaryProtocol = false,
  });
}

/// Abstract WebSocket connection interface.
///
/// Represents an established WebSocket connection with methods for
/// sending messages and closing.
abstract class WebSocketConnection {
  /// Sends a protocol message to the server.
  void send(ProtocolMessage message);

  /// Closes the connection.
  ///
  /// Optional [code] is the WebSocket close code (e.g., 1000 for normal).
  /// Optional [reason] is a human-readable close reason.
  Future<void> close({int? code, String? reason});
}
