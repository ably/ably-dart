import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'protocol_message.dart';
import 'websocket_client.dart';

/// Production WebSocket client using dart:io.
///
/// This implementation wraps dart:io WebSocket and adapts it to the
/// [WebSocketClient] interface.
class IOWebSocketClient implements WebSocketClient {
  @override
  Future<WebSocketConnection> connect(Uri url) async {
    final ws = await io.WebSocket.connect(url.toString());
    return IOWebSocketConnection(ws);
  }
}

/// Production WebSocket connection wrapping dart:io WebSocket.
class IOWebSocketConnection implements WebSocketConnection {
  IOWebSocketConnection(this._ws) {
    // Set up subscription immediately
    _subscription = _ws.listen(
      _handleMessage,
      onError: _messages.addError,
      onDone: () {
        _closed = true;
        _messages.close();
      },
      cancelOnError: false,
    );
  }

  final io.WebSocket _ws;
  final StreamController<ProtocolMessage> _messages =
      StreamController<ProtocolMessage>.broadcast();
  late final StreamSubscription<dynamic> _subscription;
  bool _closed = false;

  @override
  Stream<ProtocolMessage> get messages => _messages.stream;

  void _handleMessage(dynamic data) {
    if (data is! String) {
      return; // Ignore binary messages for now
    }

    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final message = ProtocolMessage.fromJson(json);
      _messages.add(message);
    } catch (e) {
      _messages.addError(e);
    }
  }

  @override
  void send(ProtocolMessage message) {
    if (_closed) {
      throw StateError('Connection closed');
    }
    final json = jsonEncode(message.toJson());
    _ws.add(json);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription.cancel();
    await _ws.close();
    await _messages.close();
  }
}
