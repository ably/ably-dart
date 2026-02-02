import 'dart:async';

/// Protocol message for WebSocket communication.
///
/// This is a placeholder - full implementation will include encoding/decoding.
class ProtocolMessage {
  ProtocolMessage({
    this.action,
    this.connectionId,
    this.connectionKey,
    this.channel,
  });

  final String? action;
  final String? connectionId;
  final String? connectionKey;
  final String? channel;
}

/// Abstract WebSocket transport interface.
///
/// Provides abstraction between state machine and WebSocket implementation.
/// Production uses real WebSocket, tests use mock.
abstract class WebSocketTransport {
  /// Connects to the specified URL.
  Future<void> connect({required Uri url});

  /// Sends a protocol message.
  void send(ProtocolMessage message);

  /// Stream of incoming protocol messages from server.
  Stream<ProtocolMessage> get messages;

  /// Closes the connection.
  void close();

  /// Whether the transport is currently connected.
  bool get isConnected;
}
