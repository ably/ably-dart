import '../realtime/connection.dart';
import '../realtime/protocol_message.dart';
import '../realtime/realtime.dart';
import '../realtime/realtime_channels.dart';
import '../realtime/timer_manager.dart';
import '../realtime/websocket_client.dart';
import 'base_client_impl.dart';

/// Implementation of the Ably Realtime client.
///
/// Provides access to realtime messaging, presence, and connection management.
///
/// Spec: RTC1
class RealtimeImpl extends BaseClientImpl implements Realtime {
  /// Creates a Realtime client implementation.
  RealtimeImpl({
    required super.options,
    super.httpClient,
    WebSocketClient? webSocketClient,
    TimerManager? timerManager,
  })  : _webSocketClient = webSocketClient,
        _timerManager = timerManager {
    _initialize();
  }

  final WebSocketClient? _webSocketClient;
  final TimerManager? _timerManager;
  late final TimerManager timerManager;
  late final Connection _connection;
  late final RealtimeChannels _channels;

  void _initialize() {
    timerManager = _timerManager ?? TimerManager();

    // Initialize connection
    _connection = Connection(
      options: options,
      auth: authImpl,
      timerManager: timerManager,
      webSocketClient: _webSocketClient,
      httpClient: rawHttpClient, // Pass through for ConnectivityChecker
    );

    // Initialize channels
    _channels = RealtimeChannels(
      connection: _connection,
      timerManager: timerManager,
      options: options,
      httpClient: ablyHttpClient,
    );

    // Wire up channel message dispatch
    _connection.onChannelMessage = _dispatchChannelMessage;

    // Auto-connect if enabled (RTC1c)
    if (options.autoConnect) {
      // Schedule connect for next event loop to allow constructor to complete
      Future.microtask(() => _connection.connect());
    }
  }

  @override
  Connection get connection => _connection;

  @override
  RealtimeChannels get channels => _channels;

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
