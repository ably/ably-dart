import 'package:http/http.dart' as http;

import '../auth/auth.dart';
import '../auth/client_options.dart';
import '../realtime/connection.dart';
import '../realtime/protocol_message.dart';
import '../realtime/realtime.dart';
import '../realtime/realtime_channels.dart';
import '../realtime/timer_manager.dart';
import '../realtime/websocket_client.dart';
import 'auth_impl.dart';
import 'http/http_client.dart';

/// Implementation of the Ably Realtime client.
///
/// Provides access to realtime messaging, presence, and connection management.
///
/// Spec: RTC1
class RealtimeImpl implements Realtime {
  /// Creates a Realtime client implementation.
  RealtimeImpl({
    required ClientOptions options,
    WebSocketClient? webSocketClient,
    http.Client? httpClient,
    TimerManager? timerManager,
  })  : _options = options,
        _webSocketClient = webSocketClient,
        _httpClient = httpClient,
        _timerManager = timerManager {
    _validateOptions(_options);
    _initialize();
  }

  final ClientOptions _options;
  final WebSocketClient? _webSocketClient;
  final http.Client? _httpClient;
  final TimerManager? _timerManager;
  late final TimerManager timerManager;
  late final AuthImpl _auth;
  late final Connection _connection;
  late final RealtimeChannels _channels;

  void _validateOptions(ClientOptions options) {
    // Validation is already done in ClientOptions and RestImpl
    // This is a placeholder for any Realtime-specific validation
  }

  void _initialize() {
    timerManager = _timerManager ?? TimerManager();

    // Create auth instance using the same pattern as Rest client
    final httpClient = AblyHttpClient(
      options: _options,
      httpClient: _httpClient, // Use injected client if provided
    );

    _auth = AuthImpl(
      options: _options,
      httpClient: httpClient,
    );

    // Wire up auth header provider
    httpClient.authHeaderProvider = _auth.getAuthorizationHeader;

    // Initialize connection
    _connection = Connection(
      options: _options,
      auth: _auth,
      timerManager: timerManager,
      webSocketClient: _webSocketClient,
      httpClient: _httpClient, // Pass through for ConnectivityChecker
    );

    // Initialize channels
    _channels = RealtimeChannels(
      connection: _connection,
      timerManager: timerManager,
      options: _options,
    );

    // Wire up channel message dispatch
    _connection.onChannelMessage = _dispatchChannelMessage;

    // Auto-connect if enabled (RTC1c)
    if (_options.autoConnect) {
      // Schedule connect for next event loop to allow constructor to complete
      Future.microtask(() => _connection.connect());
    }
  }

  @override
  Connection get connection => _connection;

  @override
  RealtimeChannels get channels => _channels;

  @override
  Auth get auth => _auth;

  @override
  ClientOptions get options => _options;

  @override
  String? get clientId => _auth.clientId;

  @override
  Future<void> connect() async {
    await _connection.connect();
  }

  @override
  Future<void> close() async {
    await _connection.close();
    timerManager.dispose();
  }

  void _dispatchChannelMessage(ProtocolMessage message) {
    if (message.channel == null) return;
    final channel = _channels.getIfExists(message.channel!);
    channel?.handleProtocolMessage(message);
  }
}
