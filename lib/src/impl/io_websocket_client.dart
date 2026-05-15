import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;

import '../realtime/protocol_message.dart';
import '../realtime/websocket_client.dart';

/// Production WebSocket client using dart:io.
///
/// This implementation wraps dart:io WebSocket and adapts it to the
/// [WebSocketClient] interface.
class IOWebSocketClient implements WebSocketClient {
  @override
  Future<WebSocketConnection> connect(
    Uri url,
    WebSocketListener listener, {
    bool useBinaryProtocol = false,
  }) async {
    // Wrap in an error zone to catch async SocketExceptions that dart:io
    // can post when the underlying socket is interrupted (e.g. by close()
    // during the HTTP upgrade handshake).
    final completer = Completer<io.WebSocket>();
    runZonedGuarded(() async {
      try {
        final ws = await io.WebSocket.connect(url.toString());
        if (!completer.isCompleted) completer.complete(ws);
      } catch (e) {
        if (!completer.isCompleted) completer.completeError(e);
      }
    }, (error, stack) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    });
    final ws = await completer.future;
    return IOWebSocketConnection(
      ws,
      listener,
      useBinaryProtocol: useBinaryProtocol,
    );
  }
}

/// Production WebSocket connection wrapping dart:io WebSocket.
class IOWebSocketConnection implements WebSocketConnection {
  IOWebSocketConnection(
    this._ws,
    this._listener, {
    this.useBinaryProtocol = false,
  }) {
    // Set up subscription immediately - listener is already attached
    _subscription = _ws.listen(
      _handleMessage,
      onError: (Object error) {
        // Suppress errors after intentional close (e.g. SocketException
        // from reading a closed socket during teardown).
        if (!_closed) {
          _listener.onError(error);
        }
      },
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
  final bool useBinaryProtocol;
  late final StreamSubscription<dynamic> _subscription;
  bool _closed = false;

  void _handleMessage(dynamic data) {
    try {
      Map<String, dynamic> decoded;
      if (useBinaryProtocol) {
        final bytes =
            data is Uint8List ? data : Uint8List.fromList(data as List<int>);
        decoded = _deepCast(msgpack.deserialize(bytes)) as Map<String, dynamic>;
      } else {
        if (data is! String) return;
        decoded = jsonDecode(data) as Map<String, dynamic>;
      }
      final message = ProtocolMessage.fromJson(decoded);
      _listener.onMessage(message);
    } catch (e) {
      _listener.onError(e);
    }
  }

  static dynamic _deepCast(dynamic value) {
    if (value is Map) {
      return value.map<String, dynamic>(
        (k, v) => MapEntry(k.toString(), _deepCast(v)),
      );
    }
    if (value is Uint8List) {
      return value;
    }
    if (value is List) {
      return value.map(_deepCast).toList();
    }
    return value;
  }

  @override
  void send(ProtocolMessage message) {
    if (_closed) {
      throw StateError('Connection closed');
    }
    if (useBinaryProtocol) {
      _ws.add(msgpack.serialize(message.toJson()));
    } else {
      _ws.add(jsonEncode(message.toJson()));
    }
  }

  @override
  Future<void> close({int? code, String? reason}) async {
    if (_closed) return;
    _closed = true;
    await _subscription.cancel();
    // Run close in an error zone to catch SocketExceptions that dart:io
    // posts asynchronously when the close handshake tries to read the
    // close frame from an already-closed socket (e.g. after FAILED state).
    final completer = Completer<void>();
    runZonedGuarded(() async {
      try {
        await _ws.close(code ?? io.WebSocketStatus.normalClosure, reason);
      } catch (_) {
        // Swallow synchronous/Future errors from close
      }
      if (!completer.isCompleted) completer.complete();
    }, (error, stack) {
      // Swallow async SocketExceptions from dart:io internals
      if (!completer.isCompleted) completer.complete();
    });
    await completer.future;
  }
}
