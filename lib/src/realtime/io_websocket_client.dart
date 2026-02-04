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
  Future<WebSocketConnection> connect(
      Uri url, WebSocketListener listener) async {
    final ws = await io.WebSocket.connect(url.toString());
    return IOWebSocketConnection(ws, listener);
  }
}

/// Production WebSocket connection wrapping dart:io WebSocket.
class IOWebSocketConnection implements WebSocketConnection {
  IOWebSocketConnection(this._ws, this._listener) {
    // Set up subscription immediately - listener is already attached
    _subscription = _ws.listen(
      _handleMessage,
      onError: _listener.onError,
      onDone: () {
        _closed = true;
        _listener.onClose(
          closeCode: _ws.closeCode,
          closeReason: _ws.closeReason,
        );
      },
      cancelOnError: false,
    );
  }

  final io.WebSocket _ws;
  final WebSocketListener _listener;
  late final StreamSubscription<dynamic> _subscription;
  bool _closed = false;

  void _handleMessage(dynamic data) {
    if (data is! String) {
      return; // Ignore binary messages for now
    }

    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final message = ProtocolMessage.fromJson(json);
      _listener.onMessage(message);
    } catch (e) {
      _listener.onError(e);
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
  Future<void> close({int? code, String? reason}) async {
    if (_closed) return;
    _closed = true;
    await _subscription.cancel();
    await _ws.close(code ?? io.WebSocketStatus.normalClosure, reason);
  }
}
