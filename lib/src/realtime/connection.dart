import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;

import '../auth/auth.dart';
import '../auth/client_options.dart';
import '../error/ably_exception.dart';
import '../error/error_info.dart';
import '../impl/fallback/connectivity_checker.dart';
import '../impl/fallback/error_classifier.dart';
import '../impl/fallback/host_selector.dart';
import 'connection_event.dart';
import 'connection_state.dart';
import 'connection_state_change.dart';
import 'io_websocket_client.dart';
import 'protocol_message.dart';
import 'timer_manager.dart';
import 'websocket_client.dart';

/// Manages the connection to Ably Realtime.
///
/// Spec: RTN
class Connection implements WebSocketListener {
  /// Creates a Connection instance.
  Connection({
    required ClientOptions options,
    required Auth auth,
    required TimerManager timerManager,
    WebSocketClient? webSocketClient,
    http.Client? httpClient,
    HostSelector? hostSelector,
    ConnectivityChecker? connectivityChecker,
  })  : _options = options,
        _auth = auth,
        _timerManager = timerManager,
        _webSocketClient = webSocketClient ?? IOWebSocketClient(),
        _hostSelector = hostSelector ?? HostSelector(options: options),
        _connectivityChecker =
            connectivityChecker ?? ConnectivityChecker(httpClient: httpClient),
        _state = ConnectionState.initialized;

  final ClientOptions _options;
  final Auth _auth;
  final TimerManager _timerManager;
  final WebSocketClient _webSocketClient;
  final HostSelector _hostSelector;
  final ConnectivityChecker _connectivityChecker;
  final Random _random = Random();

  ConnectionState _state;
  ErrorInfo? _errorReason;
  Completer<void>? _connectionCompleter;
  String? _id;
  String? _key;
  int? _serial;
  // DF1a: Default connectionStateTtl is 120 seconds (120000ms)
  // This is overridden by connectionDetails from CONNECTED message
  int _connectionStateTtl = 120000;
  int? _maxIdleInterval; // RTN23a
  ErrorInfo? _pendingDisconnectError; // Error to use when onClose is triggered
  DateTime? _disconnectedAt;
  DateTime? _lastActivityAt; // RTN23a - last message received time
  String? _currentHost; // RTN17e - track which host we're connected to
  bool _shouldResume = false;
  int _retryAttempt = 0; // Track retry attempts for RTB1

  WebSocketConnection? _webSocketConnection;

  final _stateChangeController =
      StreamController<ConnectionStateChange>.broadcast();

  /// The current connection state.
  ///
  /// Spec: RTN4
  ConnectionState get state => _state;

  /// Error information for the current state (if failed/suspended).
  ///
  /// Spec: RTN25
  ErrorInfo? get errorReason => _errorReason;

  /// The connection ID assigned by Ably.
  ///
  /// Null if not connected.
  ///
  /// Spec: RTN8
  String? get id => _id;

  /// The connection key that can be used to resume a connection.
  ///
  /// Null if not connected.
  ///
  /// Spec: RTN9
  String? get key => _key;

  /// The serial number of the last message received on this connection.
  ///
  /// Null if not connected.
  ///
  /// Spec: RTN10
  int? get serial => _serial;

  /// Listens to connection state changes.
  ///
  /// If [event] is provided, only emits changes matching that event.
  /// If [event] is null, emits all state changes.
  ///
  /// Spec: RTN4
  Stream<ConnectionStateChange> on([ConnectionEvent? event]) {
    if (event == null) {
      return _stateChangeController.stream;
    }

    return _stateChangeController.stream
        .where((change) => change.event == event);
  }

  /// Calls the listener immediately with null if already in the target state,
  /// otherwise registers a one-time listener for that state.
  ///
  /// Spec: RTN26
  void whenState(
    ConnectionState targetState,
    void Function(ConnectionStateChange?) listener,
  ) {
    if (_state == targetState) {
      // RTN26a: Already in target state - call immediately with null
      listener(null);
    } else {
      // RTN26b: Wait for state transition - use once
      final subscription =
          on(ConnectionEventExtension.fromState(targetState)).listen(null);
      subscription.onData((change) {
        listener(change);
        subscription.cancel();
      });
    }
  }

  /// Explicitly initiates a connection to Ably.
  ///
  /// If already connected or connecting, this is a no-op.
  ///
  /// Spec: RTN11
  Future<void> connect() async {
    switch (_state) {
      case ConnectionState.initialized:
      case ConnectionState.closed:
      case ConnectionState.failed:
      case ConnectionState.disconnected:
      case ConnectionState.suspended:
        await _startConnection();
      case ConnectionState.connecting:
      case ConnectionState.connected:
        // Already connecting or connected - no-op (RTN11e)
        break;
      case ConnectionState.closing:
        // Cancel close and start new connection (RTN11b)
        _timerManager.cancel(owner: this, name: 'close');
        await _startConnection();
    }
  }

  /// Closes the connection.
  ///
  /// Spec: RTN12
  Future<void> close() async {
    switch (_state) {
      case ConnectionState.initialized:
        // Never connected - transition directly to closed
        _transitionTo(ConnectionState.closed);
      case ConnectionState.connected:
      case ConnectionState.connecting:
      case ConnectionState.disconnected:
      case ConnectionState.suspended:
        // Transition to closing, then close WebSocket
        _transitionTo(ConnectionState.closing);
        await _closeWebSocket();
        _transitionTo(ConnectionState.closed);
      case ConnectionState.closing:
      case ConnectionState.closed:
      case ConnectionState.failed:
        // Already closing/closed - no-op
        break;
    }
  }

  /// Starts a new connection attempt.
  ///
  /// Tries primary host first, then fallback hosts if primary fails.
  ///
  /// Spec: RTN17
  Future<void> _startConnection() async {
    _transitionTo(ConnectionState.connecting);

    // Cancel any existing timers
    _timerManager.cancel(owner: this, name: 'retry');
    _timerManager.cancel(owner: this, name: 'ttl');

    // RTN17i: Get hosts to try (primary first, then fallbacks)
    final hosts = _hostSelector.getHostsToTry(
      primaryHost: _options.effectiveRealtimeHost,
    );

    Object? lastError;

    // Try each host in sequence
    for (final host in hosts) {
      try {
        await _connectToHost(host);

        // Success! Clear failure tracking if using fallback (RSC15f)
        if (!_hostSelector.isPrimaryHost(
            host, _options.effectiveRealtimeHost)) {
          _hostSelector.clearFailureTracking();
        }

        _currentHost = host;
        return; // Successfully connected
      } catch (e) {
        lastError = e;

        // HandledErrorException means error was already processed (e.g., token error)
        // Just exit the connection attempt - the handler took care of state transition
        if (e is HandledErrorException) {
          return;
        }

        // RTN14g: FatalErrorException signals ERROR message with fatal error
        // Transition to FAILED immediately without trying fallback hosts
        if (e is FatalErrorException) {
          _timerManager.cancel(owner: this, name: 'connectionTimeout');
          _transitionTo(ConnectionState.failed, error: e.errorInfo);
          return;
        }

        // Determine if we should retry with another host
        final error = _extractErrorInfo(e);

        // RTN17f1: DISCONNECTED with 5xx status (500-504) should use fallback
        if (ErrorClassifier.shouldDisconnectedUseFallback(error)) {
          _hostSelector.markHostAsFailed(host);
          continue;
        }

        if (ErrorClassifier.shouldRetryWithFallback(error)) {
          // RTN17f: Mark host as failed and try next
          _hostSelector.markHostAsFailed(host);
          continue;
        } else {
          // Non-fatal, non-retriable error - go to DISCONNECTED
          _timerManager.cancel(owner: this, name: 'connectionTimeout');
          _handleConnectionError(e);
          return;
        }
      }
    }

    // All hosts failed - check connectivity (RTN17j)
    final hasConnectivity = await _connectivityChecker.check(
      _options.effectiveConnectivityCheckUrl,
    );

    if (!hasConnectivity) {
      // No internet - report network error
      lastError = ErrorInfo(
        code: 80003,
        statusCode: 503,
        message: 'No internet connectivity detected',
      );
    }

    // Handle final failure
    _timerManager.cancel(owner: this, name: 'connectionTimeout');
    _handleConnectionError(lastError ?? 'All hosts failed');
  }

  /// Connects to a specific host.
  Future<void> _connectToHost(String host) async {
    // Build WebSocket URL for this host
    final url = await _buildWebSocketUrl(host: host);

    // Start connection timeout (RTN14c)
    _timerManager.schedule(
      owner: this,
      name: 'connectionTimeout',
      duration: Duration(milliseconds: _options.realtimeRequestTimeout),
      callback: _onConnectionTimeout,
    );

    // Create completer to wait for CONNECTED or error
    final connectionCompleter = Completer<void>();
    _connectionCompleter = connectionCompleter;

    // Connect WebSocket - pass this as the listener
    // The listener is attached before connect() returns, so no events are missed
    _webSocketConnection = await _webSocketClient.connect(url, this);

    // Wait for CONNECTED or error response from Ably
    await connectionCompleter.future;
  }

  /// Extracts ErrorInfo from various error types.
  ErrorInfo _extractErrorInfo(Object error) {
    if (error is ErrorInfo) {
      return error;
    }

    // Try to create ErrorInfo from error message
    return ErrorInfo(
      message: error.toString(),
      statusCode: 500,
      code: 80000,
    );
  }

  /// Builds the WebSocket URL for connection.
  ///
  /// If [host] is provided, uses that host instead of the default.
  /// This allows connection to fallback hosts.
  ///
  /// Spec: RTN17
  Future<Uri> _buildWebSocketUrl({String? host}) async {
    final scheme = _options.tls ? 'wss' : 'ws';
    final effectiveHost = host ?? _options.effectiveRealtimeHost;
    final port = _options.effectivePort;

    final queryParams = <String, String>{};

    // Add format parameter
    queryParams['format'] = 'json';

    // Add echo parameter (RTN1a)
    if (!_options.echoMessages) {
      queryParams['echo'] = 'false';
    }

    // Add v parameter (protocol version)
    queryParams['v'] = '1.2';

    // Add resume parameter if resuming (RTN15b)
    if (_shouldResume && _key != null) {
      queryParams['resume'] = _key!;
      if (_serial != null) {
        queryParams['connectionSerial'] = _serial.toString();
      }
    }

    // Add authentication (RSA4: authCallback/authUrl/token take precedence over key)
    if (_auth.method == AuthMethod.token) {
      // Token auth - get valid token (reuses cached token if not expired)
      final tokenDetails = await _auth.getValidToken();
      if (tokenDetails.token != null) {
        queryParams['accessToken'] = tokenDetails.token!;
      }
    } else if (_options.key != null) {
      // Basic auth with API key
      queryParams['key'] = _options.key!;
    }

    // Add clientId if set
    if (_options.clientId != null) {
      queryParams['clientId'] = _options.clientId!;
    }

    // Add transport params if set
    if (_options.transportParams != null) {
      queryParams.addAll(_options.transportParams!);
    }

    final portStr = (port == 443 || port == 80) ? '' : ':$port';
    final uri = Uri.parse('$scheme://$effectiveHost$portStr/');
    return uri.replace(queryParameters: queryParams);
  }

  // WebSocketListener implementation

  @override
  void onMessage(ProtocolMessage message) {
    // RTN23a: Any message from server resets idle timer
    _lastActivityAt = clock.now();
    _scheduleIdleTimeout();

    switch (message.action) {
      case ProtocolAction.connected:
        _handleConnected(message);
      case ProtocolAction.disconnected:
        _handleDisconnected(message);
      case ProtocolAction.closed:
        _handleClosed(message);
      case ProtocolAction.error:
        _handleError(message);
      case ProtocolAction.heartbeat:
        // Echo heartbeat back
        _sendHeartbeat();
      default:
        // Other message types handled by channels
        break;
    }
  }

  @override
  void onError(Object error) {
    print('WebSocket error: $error');
    // WebSocket errors will trigger onClose, so we handle it there
  }

  @override
  void onClose({int? closeCode, String? closeReason}) {
    if (_state == ConnectionState.closing ||
        _state == ConnectionState.closed ||
        _state == ConnectionState.failed ||
        _state == ConnectionState.disconnected) {
      // Expected close, already in terminal state, or already handled
      return;
    }

    // Use pending error if set (e.g., from idle timeout), otherwise generic
    final error = _pendingDisconnectError ??
        ErrorInfo(
          code: 80003,
          statusCode: 503,
          message: 'Connection lost',
        );
    _pendingDisconnectError = null; // Clear for next time

    // If we're in initial connection, complete with error for fallback retry
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      final completer = _connectionCompleter!;
      _connectionCompleter = null;
      scheduleMicrotask(() {
        completer.completeError(error);
      });
      return;
    }

    _shouldResume = true;
    _transitionTo(ConnectionState.disconnected, error: error);
    _scheduleReconnect();
  }

  /// Handles CONNECTED protocol message (RTN24).
  void _handleConnected(ProtocolMessage message) {
    // Cancel connection timeout
    _timerManager.cancel(owner: this, name: 'connectionTimeout');

    // Reset retry attempt counter on successful connection (RTB1)
    _retryAttempt = 0;

    final previousId = _id;
    final wasAlreadyConnected = _state == ConnectionState.connected;

    // Update connection details (RTN21, RTN24)
    _id = message.connectionId;
    _key = message.connectionKey ?? message.connectionDetails?.connectionKey;
    _serial = message.msgSerial ?? -1;

    // Update connection state TTL (DF1a - override default if server provides one)
    if (message.connectionDetails?.connectionStateTtl != null) {
      _connectionStateTtl = message.connectionDetails!.connectionStateTtl!;
    }

    // Update maxIdleInterval for heartbeat timeout (RTN23a)
    if (message.connectionDetails?.maxIdleInterval != null) {
      _maxIdleInterval = message.connectionDetails!.maxIdleInterval;
      // Restart idle timeout with new interval
      if (wasAlreadyConnected) {
        _scheduleIdleTimeout();
      }
    }

    // RTN24: If already CONNECTED, emit UPDATE event instead of CONNECTED
    if (wasAlreadyConnected) {
      // Emit UPDATE event (not a state change)
      _stateChangeController.add(
        ConnectionStateChange(
          current: ConnectionState.connected,
          previous: ConnectionState.connected,
          event: ConnectionEvent.update,
          reason: message.error, // RTN24: include error if present
        ),
      );
      return;
    }

    // Check if resume succeeded or failed
    if (previousId != null && _id != previousId) {
      // Resume failed - got new connection ID (RTN15c7)
      _shouldResume = false;

      // Could set error reason to indicate resume failure
      final resumeError = ErrorInfo(
        code: 80008,
        statusCode: 400,
        message: 'Resume failed',
      );

      _transitionTo(ConnectionState.connected, error: resumeError);
    } else {
      // Successful connection or resume
      _shouldResume = false;
      _disconnectedAt = null;
      _transitionTo(ConnectionState.connected);
    }

    // Start idle timeout after successful connection (RTN23a)
    _scheduleIdleTimeout();

    // Complete connection attempt
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.complete();
      _connectionCompleter = null;
    }
  }

  /// Handles DISCONNECTED protocol message (RTN15h).
  void _handleDisconnected(ProtocolMessage message) {
    _timerManager.cancel(owner: this, name: 'connectionTimeout');

    final error = message.error ??
        ErrorInfo(
          code: 80003,
          statusCode: 503,
          message: 'Disconnected',
        );

    // If we're in initial connection and get DISCONNECTED, complete with error
    // so fallback hosts can be tried (RTN17f1)
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      final completer = _connectionCompleter!;
      _connectionCompleter = null;
      scheduleMicrotask(() {
        completer.completeError(error);
      });
      _closeWebSocket();
      return;
    }

    // Check if it's a token error (RTN14b, RTN15h)
    if (_isTokenError(error)) {
      _handleTokenError(error);
    } else {
      // Non-token error - prepare to resume (RTN15h3)
      _shouldResume = true;
      _transitionTo(ConnectionState.disconnected, error: error);
      _scheduleReconnect();
    }
  }

  /// Handles CLOSED protocol message.
  void _handleClosed(ProtocolMessage message) {
    _timerManager.cancel(owner: this, name: 'connectionTimeout');
    _closeWebSocket();
    _transitionTo(ConnectionState.closed, error: message.error);
  }

  /// Handles ERROR protocol message (RTN14g, RTN15j).
  void _handleError(ProtocolMessage message) {
    _timerManager.cancel(owner: this, name: 'connectionTimeout');

    final error = message.error ??
        ErrorInfo(
          code: 50000,
          statusCode: 500,
          message: 'Unknown error',
        );

    // Error with empty channel is connection-level error
    if (message.channel == null || message.channel!.isEmpty) {
      // RTN14b: Check if it's a token error - handle specially for renewal
      if (_isTokenError(error)) {
        // Complete with HandledErrorException to signal catch block to ignore
        if (_connectionCompleter != null &&
            !_connectionCompleter!.isCompleted) {
          final completer = _connectionCompleter!;
          _connectionCompleter = null;
          scheduleMicrotask(() {
            completer.completeError(const HandledErrorException());
          });
        }
        _closeWebSocket();
        _handleTokenError(error);
        return;
      }

      // If we're in initial connection and get ERROR, complete with error
      if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
        // RTN14g: Fatal errors should transition to FAILED, not retry
        // Wrap in FatalErrorException to signal catch block not to retry
        final errorToThrow =
            _isFatalError(error) ? FatalErrorException(error) : error;
        // Schedule the error completion asynchronously to avoid throwing
        // during the synchronous listener callback
        final completer = _connectionCompleter!;
        _connectionCompleter = null;
        scheduleMicrotask(() {
          completer.completeError(errorToThrow);
        });
        _closeWebSocket();
        return;
      }

      // Check if it's a fatal error
      if (_isFatalError(error)) {
        _closeWebSocket();
        _transitionTo(ConnectionState.failed, error: error);
      } else {
        // Recoverable error
        _shouldResume = true;
        _transitionTo(ConnectionState.disconnected, error: error);
        _scheduleReconnect();
      }
    }
  }

  /// Handles token errors (RTN14b, RTN15h).
  void _handleTokenError(ErrorInfo error) {
    // Check if we can renew the token
    if (_canRenewToken()) {
      // Try to renew token and reconnect (RTN15h2)
      _shouldResume = true;
      _transitionTo(ConnectionState.disconnected, error: error);
      _scheduleTokenRenewal();
    } else {
      // Cannot renew - transition to FAILED (RTN15h1)
      _closeWebSocket();
      _transitionTo(ConnectionState.failed, error: error);
    }
  }

  /// Checks if error is a token error.
  bool _isTokenError(ErrorInfo error) {
    return error.code == 40140 ||
        error.code == 40141 ||
        error.code == 40142 ||
        error.statusCode == 401;
  }

  /// Checks if error is fatal (non-recoverable).
  bool _isFatalError(ErrorInfo error) {
    // 5xxxx errors are generally fatal
    if (error.code != null && error.code! >= 50000 && error.code! < 60000) {
      return true;
    }

    // 400 errors (except token errors) are fatal
    if (error.statusCode == 400 && !_isTokenError(error)) {
      return true;
    }

    return false;
  }

  /// Checks if we can renew the token.
  bool _canRenewToken() {
    // Can renew if we have key, authUrl, or authCallback
    return _options.key != null ||
        _options.authUrl != null ||
        _options.authCallback != null;
  }

  /// Schedules token renewal and reconnection.
  void _scheduleTokenRenewal() {
    _timerManager.schedule(
      owner: this,
      name: 'tokenRenewal',
      duration: const Duration(milliseconds: 100),
      callback: () async {
        try {
          // Try to get a new token
          await _auth.authorize();
          // Token renewed, reconnect
          _shouldResume = true;
          await _startConnection();
        } catch (e) {
          // Token renewal failed
          final error = ErrorInfo(
            code: 40140,
            statusCode: 401,
            message: 'Token renewal failed',
            cause: e,
          );
          _transitionTo(ConnectionState.disconnected, error: error);
          _scheduleReconnect();
        }
      },
    );
  }

  /// Handles connection timeout (RTN14c).
  void _onConnectionTimeout() {
    if (_state != ConnectionState.connecting) {
      return;
    }

    final error = ErrorInfo(
      code: 80014,
      statusCode: 408,
      message: 'Connection timeout',
    );

    // If we're in initial connection, complete with error for fallback retry
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      final completer = _connectionCompleter!;
      _connectionCompleter = null;
      scheduleMicrotask(() {
        completer.completeError(error);
      });
      _closeWebSocket();
      return;
    }

    _closeWebSocket();
    _shouldResume = false;
    _transitionTo(ConnectionState.disconnected, error: error);
    _scheduleReconnect();
  }

  /// Handles connection errors during opening.
  void _handleConnectionError(Object error) {
    final errorInfo = ErrorInfo(
      code: 80000,
      statusCode: 500,
      message: 'Connection failed: $error',
      cause: error,
    );

    _shouldResume = false;
    _transitionTo(ConnectionState.disconnected, error: errorInfo);
    _scheduleReconnect();
  }

  /// Schedules a reconnection attempt (RTN14d).
  ///
  /// Per RTN15a/RTN15h3: If the connection was previously CONNECTED (indicated
  /// by _shouldResume being true and _retryAttempt being 0), the first
  /// reconnection attempt is immediate. Subsequent attempts use backoff delay.
  void _scheduleReconnect() {
    if (_state != ConnectionState.disconnected &&
        _state != ConnectionState.suspended) {
      return;
    }

    // Check if we should transition to SUSPENDED (RTN14e)
    if (_state == ConnectionState.disconnected && _shouldCheckTtl()) {
      _shouldResume = false;
      _transitionTo(ConnectionState.suspended, error: _errorReason);
      // Continue to schedule retry from SUSPENDED state (RTN14f)
    }

    // RTN15a/RTN15h3: If we were previously connected and this is the first
    // retry attempt, reconnect immediately (no delay)
    final isImmediateReconnect = _shouldResume &&
        _retryAttempt == 0 &&
        _state == ConnectionState.disconnected;

    if (isImmediateReconnect) {
      // Immediate reconnection - use scheduleMicrotask to avoid stack overflow
      // and allow current event processing to complete
      scheduleMicrotask(() {
        if (_state == ConnectionState.disconnected) {
          _retryAttempt++;
          _startConnection();
        }
      });
      return;
    }

    // Calculate retry delay with incremental backoff and jitter (RTB1)
    final baseTimeout = _state == ConnectionState.suspended
        ? _options.suspendedRetryTimeout
        : _options.disconnectedRetryTimeout;

    // RTB1a: backoff coefficient is min((n + 2) / 3, 2)
    // Results in sequence [1, 4/3, 5/3, 2, 2, ...]
    final backoffCoefficient = ((_retryAttempt + 2) / 3).clamp(1.0, 2.0);

    // RTB1b: jitter coefficient is random between 0.8 and 1.0
    final jitterCoefficient = 0.8 + (_random.nextDouble() * 0.2);

    final retryDelay =
        (baseTimeout * backoffCoefficient * jitterCoefficient).round();

    _timerManager.schedule(
      owner: this,
      name: 'retry',
      duration: Duration(milliseconds: retryDelay),
      callback: () {
        if (_state == ConnectionState.disconnected ||
            _state == ConnectionState.suspended) {
          // RTN14e: Check TTL before reconnecting from DISCONNECTED
          // If TTL has elapsed, transition to SUSPENDED instead
          if (_state == ConnectionState.disconnected && _shouldCheckTtl()) {
            _shouldResume = false;
            _transitionTo(ConnectionState.suspended, error: _errorReason);
            // RTN14f: Continue retrying from SUSPENDED
            _scheduleReconnect();
            return;
          }
          _retryAttempt++; // Increment for next retry
          _startConnection();
        }
      },
    );

    // Schedule TTL check if in DISCONNECTED state
    if (_state == ConnectionState.disconnected) {
      _scheduleTtlCheck();
    }
  }

  /// Checks if we should transition to SUSPENDED based on TTL.
  bool _shouldCheckTtl() {
    if (_disconnectedAt == null) {
      return false;
    }

    final now = clock.now();
    final elapsed = now.difference(_disconnectedAt!).inMilliseconds;
    return elapsed >= _connectionStateTtl;
  }

  /// Schedules a TTL check (RTN14e).
  void _scheduleTtlCheck() {
    _disconnectedAt ??= clock.now();

    final ttlRemaining = _connectionStateTtl -
        clock.now().difference(_disconnectedAt!).inMilliseconds;

    if (ttlRemaining <= 0) {
      // Already past TTL
      _shouldResume = false;
      _transitionTo(ConnectionState.suspended, error: _errorReason);
      return;
    }

    _timerManager.schedule(
      owner: this,
      name: 'ttl',
      duration: Duration(milliseconds: ttlRemaining),
      callback: () {
        if (_state == ConnectionState.disconnected) {
          _shouldResume = false;
          _transitionTo(ConnectionState.suspended, error: _errorReason);
          // Suspended state still retries (RTN14f)
          _scheduleReconnect();
        }
      },
    );
  }

  /// Schedules idle timeout check (RTN23a).
  ///
  /// If no activity for maxIdleInterval + realtimeRequestTimeout,
  /// the connection is considered lost.
  void _scheduleIdleTimeout() {
    // Only schedule if connected and have maxIdleInterval
    if (_state != ConnectionState.connected || _maxIdleInterval == null) {
      return;
    }

    // Cancel existing idle timeout
    _timerManager.cancel(owner: this, name: 'idleTimeout');

    // RTN23a: maxIdleInterval + realtimeRequestTimeout
    final idleTimeout = _maxIdleInterval! + _options.realtimeRequestTimeout;

    _timerManager.schedule(
      owner: this,
      name: 'idleTimeout',
      duration: Duration(milliseconds: idleTimeout),
      callback: _onIdleTimeout,
    );
  }

  /// Handles idle timeout - no activity from server (RTN23a).
  ///
  /// When no activity is received for maxIdleInterval + realtimeRequestTimeout,
  /// the client closes the WebSocket. The onClose handler will then transition
  /// the connection to DISCONNECTED and trigger reconnection.
  void _onIdleTimeout() {
    if (_state != ConnectionState.connected) {
      return;
    }

    // Store error for use in onClose handler
    _pendingDisconnectError = ErrorInfo(
      code: 80003,
      statusCode: 408,
      message: 'Connection idle timeout - no activity from server',
    );

    // Close the WebSocket - this triggers onClose which handles state transition
    _closeWebSocket();
  }

  /// Sends a heartbeat message.
  void _sendHeartbeat() {
    if (_webSocketConnection == null) {
      return;
    }

    try {
      final message = ProtocolMessage(action: ProtocolAction.heartbeat);
      _webSocketConnection!.send(message);
    } catch (e) {
      print('Error sending heartbeat: $e');
    }
  }

  /// Closes the WebSocket connection.
  ///
  /// Captures the connection reference immediately to ensure the close
  /// completes even if _webSocketConnection is reassigned during async
  /// operations (e.g., during reconnection).
  ///
  /// The connection reference is cleared synchronously, and close() is
  /// called on the captured reference. This ensures that:
  /// 1. New connections aren't affected by this close
  /// 2. The onClose callback (if synchronous) triggers state transitions
  Future<void> _closeWebSocket() {
    // Cancel idle timeout when closing connection
    _timerManager.cancel(owner: this, name: 'idleTimeout');

    // Capture reference before clearing - ensures close completes
    // even if reconnection assigns a new connection
    final connection = _webSocketConnection;
    _webSocketConnection = null;

    if (connection == null) {
      return Future.value();
    }

    // close() may trigger onClose synchronously (in mock) or
    // asynchronously (in real WebSocket)
    return connection.close();
  }

  /// Transitions to a new state and emits a state change event.
  void _transitionTo(
    ConnectionState newState, {
    ErrorInfo? error,
    int? retryIn,
  }) {
    if (_state == newState && error == null) {
      return;
    }

    final previous = _state;
    _state = newState;

    // Update error reason if provided
    if (error != null) {
      _errorReason = error;
    } else if (newState == ConnectionState.connected ||
        newState == ConnectionState.closed) {
      // Clear error when successfully connected or explicitly closed
      _errorReason = null;
    }

    // Clear connection details when in terminal states
    if (newState == ConnectionState.closed ||
        newState == ConnectionState.failed) {
      _id = null;
      _key = null;
      _serial = null;
      _shouldResume = false;
      _disconnectedAt = null;
    }

    // Track disconnection time for TTL (RTN14e)
    // Only set _disconnectedAt when first entering disconnected state,
    // not when returning to it after failed reconnection attempts
    if (newState == ConnectionState.disconnected && _disconnectedAt == null) {
      _disconnectedAt = clock.now();
    }

    // Map state to event
    final event = ConnectionEventExtension.fromState(newState);

    final change = ConnectionStateChange(
      event: event,
      current: newState,
      previous: previous,
      reason: error ?? _errorReason,
      retryIn: retryIn,
    );

    _stateChangeController.add(change);
  }

  /// Disposes resources used by this connection.
  void dispose() {
    _closeWebSocket();
    _timerManager.cancelAll(owner: this);
    _stateChangeController.close();
  }
}
