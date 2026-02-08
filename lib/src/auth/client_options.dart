import 'package:meta/meta.dart';

import '../logging/log_level.dart';
import 'auth_options.dart';
import 'token_details.dart';
import 'token_params.dart';

/// Configuration options for the Ably REST client.
///
/// Extends [AuthOptions] with client-specific configuration.
///
/// Spec: TO, RSC1, REC1, REC2, REC3
@immutable
class ClientOptions extends AuthOptions {
  /// Creates a ClientOptions instance.
  ///
  /// Throws [ArgumentError] if conflicting options are set.
  ///
  /// REC1b1: [endpoint] conflicts with [environment], [restHost],
  /// [realtimeHost], and [fallbackHostsUseDefault].
  factory ClientOptions({
    // AuthOptions fields
    String? key,
    String? authUrl,
    String? authMethod,
    Map<String, String>? authHeaders,
    Map<String, String>? authParams,
    AuthCallback? authCallback,
    TokenDetails? tokenDetails,
    String? token,
    bool? queryTime,
    bool? useTokenAuth,
    // ClientOptions specific fields
    String? clientId,
    LogLevel logLevel = LogLevel.info,
    bool tls = true,
    String? endpoint,
    String? restHost,
    String? realtimeHost,
    int? port,
    int? tlsPort,
    String? environment,
    List<String>? fallbackHosts,
    bool? fallbackHostsUseDefault,
    int httpMaxRetryCount = 3,
    int httpOpenTimeout = 4000,
    int httpRequestTimeout = 10000,
    int fallbackRetryTimeout = 600000,
    bool useBinaryProtocol = true,
    bool idempotentRestPublishing = true,
    bool addRequestIds = false,
    int maxMessageSize = 65536,
    TokenParams? defaultTokenParams,
    Map<String, String>? transportParams,
    Map<String, String>? agents,
    String? connectivityCheckUrl,
    bool echoMessages = true,
    bool queueMessages = true,
    bool autoConnect = true,
    int realtimeRequestTimeout = 10000,
    int disconnectedRetryTimeout = 15000,
    int suspendedRetryTimeout = 30000,
  }) {
    // REC1b1: Endpoint conflicts with deprecated options
    if (endpoint != null) {
      if (environment != null) {
        throw ArgumentError(
          'Cannot set both endpoint and environment. '
          'Use endpoint for all new configuration.',
        );
      }
      if (restHost != null) {
        throw ArgumentError(
          'Cannot set both endpoint and restHost. '
          'Use endpoint for all new configuration.',
        );
      }
      if (realtimeHost != null) {
        throw ArgumentError(
          'Cannot set both endpoint and realtimeHost. '
          'Use endpoint for all new configuration.',
        );
      }
      if (fallbackHostsUseDefault != null) {
        throw ArgumentError(
          'Cannot set both endpoint and fallbackHostsUseDefault. '
          'Use endpoint for all new configuration.',
        );
      }
    }

    // REC2a1: fallbackHosts conflicts with fallbackHostsUseDefault
    if (fallbackHosts != null && fallbackHostsUseDefault != null) {
      throw ArgumentError(
        'Cannot set both fallbackHosts and fallbackHostsUseDefault.',
      );
    }

    // REC1c1: Environment conflicts with restHost (TO3k)
    if (environment != null && restHost != null) {
      throw ArgumentError(
        'Cannot set both restHost and environment. '
        'Use restHost for custom hosts or environment for Ably environments.',
      );
    }

    return ClientOptions._(
      key: key,
      authUrl: authUrl,
      authMethod: authMethod,
      authHeaders: authHeaders,
      authParams: authParams,
      authCallback: authCallback,
      tokenDetails: tokenDetails,
      token: token,
      queryTime: queryTime,
      useTokenAuth: useTokenAuth,
      clientId: clientId,
      logLevel: logLevel,
      tls: tls,
      endpoint: endpoint,
      restHost: restHost,
      realtimeHost: realtimeHost,
      port: port,
      tlsPort: tlsPort,
      environment: environment,
      fallbackHosts: fallbackHosts,
      fallbackHostsUseDefault: fallbackHostsUseDefault,
      httpMaxRetryCount: httpMaxRetryCount,
      httpOpenTimeout: httpOpenTimeout,
      httpRequestTimeout: httpRequestTimeout,
      fallbackRetryTimeout: fallbackRetryTimeout,
      useBinaryProtocol: useBinaryProtocol,
      idempotentRestPublishing: idempotentRestPublishing,
      addRequestIds: addRequestIds,
      maxMessageSize: maxMessageSize,
      defaultTokenParams: defaultTokenParams,
      transportParams: transportParams,
      agents: agents,
      connectivityCheckUrl: connectivityCheckUrl,
      echoMessages: echoMessages,
      queueMessages: queueMessages,
      autoConnect: autoConnect,
      realtimeRequestTimeout: realtimeRequestTimeout,
      disconnectedRetryTimeout: disconnectedRetryTimeout,
      suspendedRetryTimeout: suspendedRetryTimeout,
    );
  }

  /// Internal const constructor.
  const ClientOptions._({
    // AuthOptions fields
    super.key,
    super.authUrl,
    super.authMethod,
    super.authHeaders,
    super.authParams,
    super.authCallback,
    super.tokenDetails,
    super.token,
    super.queryTime,
    super.useTokenAuth,
    // ClientOptions specific fields
    this.clientId,
    this.logLevel = LogLevel.info,
    this.tls = true,
    this.endpoint,
    this.restHost,
    this.realtimeHost,
    this.port,
    this.tlsPort,
    this.environment,
    this.fallbackHosts,
    this.fallbackHostsUseDefault,
    this.httpMaxRetryCount = 3,
    this.httpOpenTimeout = 4000,
    this.httpRequestTimeout = 10000,
    this.fallbackRetryTimeout = 600000,
    this.useBinaryProtocol = true,
    this.idempotentRestPublishing = true,
    this.addRequestIds = false,
    this.maxMessageSize = 65536,
    this.defaultTokenParams,
    this.transportParams,
    this.agents,
    this.connectivityCheckUrl,
    this.echoMessages = true,
    this.queueMessages = true,
    this.autoConnect = true,
    this.realtimeRequestTimeout = 10000,
    this.disconnectedRetryTimeout = 15000,
    this.suspendedRetryTimeout = 30000,
  });

  /// Creates ClientOptions from an API key string.
  ///
  /// Throws [ArgumentError] if the key format is invalid.
  /// Valid format is: `keyName:keySecret`
  ///
  /// Spec: RSC1
  factory ClientOptions.fromKey(String key) {
    if (key.isEmpty) {
      throw ArgumentError.value(key, 'key', 'API key cannot be empty');
    }
    final parts = key.split(':');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      throw ArgumentError.value(
        key,
        'key',
        'Invalid API key format. Expected format: keyName:keySecret',
      );
    }
    return ClientOptions._(key: key);
  }

  /// The clientId to use for this client.
  ///
  /// The clientId identifies the client to Ably and is associated with
  /// all messages and presence events.
  final String? clientId;

  /// Log level for SDK logging.
  final LogLevel logLevel;

  /// Whether to use TLS for connections.
  ///
  /// Defaults to true.
  final bool tls;

  /// Endpoint configuration (REC1b).
  ///
  /// Can be:
  /// - An explicit hostname (contains '.' or is 'localhost' or IPv6)
  /// - A nonprod routing policy (format: 'nonprod:id')
  /// - A production routing policy (other values)
  final String? endpoint;

  /// Custom REST host (deprecated, use [endpoint]).
  final String? restHost;

  /// Custom realtime host (deprecated, use [endpoint]).
  final String? realtimeHost;

  /// Custom non-TLS port.
  final int? port;

  /// Custom TLS port.
  final int? tlsPort;

  /// Environment (e.g., 'sandbox') (deprecated, use [endpoint]).
  final String? environment;

  /// List of fallback hosts to use if the primary fails.
  final List<String>? fallbackHosts;

  /// Whether to use default fallback hosts (deprecated).
  final bool? fallbackHostsUseDefault;

  /// Maximum number of HTTP request retries.
  ///
  /// Defaults to 3.
  final int httpMaxRetryCount;

  /// HTTP connection open timeout in milliseconds.
  ///
  /// Defaults to 4000.
  final int httpOpenTimeout;

  /// HTTP request timeout in milliseconds.
  ///
  /// Defaults to 10000.
  final int httpRequestTimeout;

  /// Fallback retry timeout in milliseconds.
  ///
  /// Defaults to 600000 (10 minutes).
  final int fallbackRetryTimeout;

  /// Whether to use binary protocol (MessagePack) instead of JSON.
  ///
  /// Defaults to false (use JSON).
  final bool useBinaryProtocol;

  /// Whether to use idempotent REST publishing.
  ///
  /// When true, the SDK generates message IDs to enable retries
  /// without duplicate publishing.
  ///
  /// Defaults to true.
  final bool idempotentRestPublishing;

  /// Whether to add request IDs to every HTTP request.
  ///
  /// Defaults to false.
  final bool addRequestIds;

  /// Maximum message size in bytes.
  ///
  /// Defaults to 65536 (64KB).
  final int maxMessageSize;

  /// Default token parameters for token requests.
  final TokenParams? defaultTokenParams;

  /// Custom transport parameters to add to connection.
  final Map<String, String>? transportParams;

  /// Custom agent identifiers to add to the user-agent header.
  final Map<String, String>? agents;

  /// Custom connectivity check URL (REC3b).
  final String? connectivityCheckUrl;

  /// Whether to echo messages back to the sender.
  ///
  /// When true (default), messages published by this client will be echoed
  /// back to it on the same channel. When false, messages will not be echoed.
  ///
  /// This is sent as a query parameter in the WebSocket connection URL.
  ///
  /// Spec: RTC1a
  final bool echoMessages;

  /// Whether to queue messages when the connection is not CONNECTED.
  ///
  /// When true (default), messages published while the connection is
  /// INITIALIZED, CONNECTING, or DISCONNECTED are queued and sent once
  /// the connection becomes CONNECTED. When false, publishing in those
  /// states fails immediately.
  ///
  /// Spec: RTL6c2
  final bool queueMessages;

  /// Whether to automatically connect when the Realtime client is created.
  ///
  /// Defaults to true. Set to false to delay connection until connect() is called.
  final bool autoConnect;

  /// Timeout in milliseconds for realtime connection requests.
  ///
  /// Defaults to 10000 (10 seconds).
  final int realtimeRequestTimeout;

  /// Timeout in milliseconds before retrying from DISCONNECTED state.
  ///
  /// Defaults to 15000 (15 seconds).
  final int disconnectedRetryTimeout;

  /// Timeout in milliseconds before retrying from SUSPENDED state.
  ///
  /// Defaults to 30000 (30 seconds).
  final int suspendedRetryTimeout;

  /// Parses the endpoint to determine if it's an explicit hostname (REC1b2).
  ///
  /// Returns true if:
  /// - Contains a period (e.g., 'custom.host.com')
  /// - Is 'localhost'
  /// - Is an IPv6 address (contains '[')
  bool get _isExplicitHostname {
    if (endpoint == null) return false;
    return endpoint!.contains('.') ||
        endpoint!.toLowerCase() == 'localhost' ||
        endpoint!.contains('[');
  }

  /// Returns true if endpoint is a nonprod routing policy (REC1b3).
  ///
  /// Format: 'nonprod:id'
  bool get _isNonprodRoutingPolicy {
    if (endpoint == null) return false;
    return endpoint!.startsWith('nonprod:');
  }

  /// Returns the routing policy ID from the endpoint.
  String? get _routingPolicyId {
    if (endpoint == null) return null;
    if (_isNonprodRoutingPolicy) {
      return endpoint!.substring('nonprod:'.length);
    }
    if (!_isExplicitHostname) {
      return endpoint;
    }
    return null;
  }

  /// Returns the effective REST host (REC1).
  String get effectiveRestHost {
    // REC1b2: Endpoint as explicit hostname
    if (endpoint != null && _isExplicitHostname) {
      return endpoint!;
    }

    // REC1b3: Endpoint as nonprod routing policy
    if (endpoint != null && _isNonprodRoutingPolicy) {
      final id = _routingPolicyId;
      return '$id.nonprod-realtime.ably.net';
    }

    // REC1b4: Endpoint as production routing policy
    if (endpoint != null && !_isExplicitHostname) {
      final id = _routingPolicyId;
      return '$id.realtime.ably.net';
    }

    // REC1d1: Deprecated restHost option
    if (restHost != null) return restHost!;

    // REC1c2: Deprecated environment option
    if (environment != null) return '$environment-rest.ably.io';

    // REC1a: Default primary domain
    return 'rest.ably.io';
  }

  /// Returns the effective realtime host.
  String get effectiveRealtimeHost {
    // Similar logic to REST host but for realtime
    if (endpoint != null && _isExplicitHostname) {
      return endpoint!;
    }

    if (endpoint != null && _isNonprodRoutingPolicy) {
      final id = _routingPolicyId;
      return '$id.nonprod-realtime.ably.net';
    }

    if (endpoint != null && !_isExplicitHostname) {
      final id = _routingPolicyId;
      return '$id.realtime.ably.net';
    }

    if (realtimeHost != null) return realtimeHost!;

    if (environment != null) return '$environment-realtime.ably.io';

    return 'realtime.ably.io';
  }

  /// Returns the effective port.
  int get effectivePort {
    if (tls) {
      return tlsPort ?? 443;
    } else {
      return port ?? 80;
    }
  }

  /// Returns the base URL for REST requests.
  String get restBaseUrl {
    final scheme = tls ? 'https' : 'http';
    final hostPort = effectivePort == (tls ? 443 : 80)
        ? effectiveRestHost
        : '$effectiveRestHost:$effectivePort';
    return '$scheme://$hostPort';
  }

  /// Returns the effective fallback hosts (REC2).
  ///
  /// Returns null if fallbacks should not be used.
  List<String>? get effectiveFallbackHosts {
    // REC2a2: Custom fallbackHosts option takes precedence
    if (fallbackHosts != null) {
      return fallbackHosts;
    }

    // REC2c2: Explicit hostname endpoint has no fallbacks
    if (endpoint != null && _isExplicitHostname) {
      return null;
    }

    // REC2c3: Nonprod routing policy fallback domains
    if (endpoint != null && _isNonprodRoutingPolicy) {
      final id = _routingPolicyId;
      return [
        '$id.a-fallback.nonprod-realtime.ably.net',
        '$id.b-fallback.nonprod-realtime.ably.net',
        '$id.c-fallback.nonprod-realtime.ably.net',
        '$id.d-fallback.nonprod-realtime.ably.net',
        '$id.e-fallback.nonprod-realtime.ably.net',
      ];
    }

    // REC2c4: Production routing policy fallback domains (via endpoint)
    if (endpoint != null && !_isExplicitHostname) {
      final id = _routingPolicyId;
      return [
        '$id.a-fallback.realtime.ably.net',
        '$id.b-fallback.realtime.ably.net',
        '$id.c-fallback.realtime.ably.net',
        '$id.d-fallback.realtime.ably.net',
        '$id.e-fallback.realtime.ably.net',
      ];
    }

    // REC2c6: Custom restHost or realtimeHost has no fallbacks
    if (restHost != null || realtimeHost != null) {
      return null;
    }

    // REC2c5: Production routing policy fallback domains (via deprecated environment)
    if (environment != null) {
      return [
        '$environment.a-fallback.realtime.ably.net',
        '$environment.b-fallback.realtime.ably.net',
        '$environment.c-fallback.realtime.ably.net',
        '$environment.d-fallback.realtime.ably.net',
        '$environment.e-fallback.realtime.ably.net',
      ];
    }

    // REC2b: Deprecated fallbackHostsUseDefault option
    if (fallbackHostsUseDefault == false) {
      return null;
    }

    // REC2c1: Default fallback domains
    return null; // Will use defaultFallbackHosts from constants
  }

  /// Returns the connectivity check URL (REC3).
  String get effectiveConnectivityCheckUrl {
    // REC3b: Custom connectivity check URL
    if (connectivityCheckUrl != null) {
      return connectivityCheckUrl!;
    }

    // REC3a: Default connectivity check URL
    return 'https://internet-up.ably-realtime.com/is-the-internet-up.txt';
  }

  /// Creates a copy of this ClientOptions with the given fields replaced.
  @override
  ClientOptions copyWith({
    String? key,
    String? authUrl,
    String? authMethod,
    Map<String, String>? authHeaders,
    Map<String, String>? authParams,
    AuthCallback? authCallback,
    TokenDetails? tokenDetails,
    String? token,
    bool? queryTime,
    bool? useTokenAuth,
    String? clientId,
    LogLevel? logLevel,
    bool? tls,
    String? endpoint,
    String? restHost,
    String? realtimeHost,
    int? port,
    int? tlsPort,
    String? environment,
    List<String>? fallbackHosts,
    bool? fallbackHostsUseDefault,
    int? httpMaxRetryCount,
    int? httpOpenTimeout,
    int? httpRequestTimeout,
    int? fallbackRetryTimeout,
    bool? useBinaryProtocol,
    bool? idempotentRestPublishing,
    bool? addRequestIds,
    int? maxMessageSize,
    TokenParams? defaultTokenParams,
    Map<String, String>? transportParams,
    Map<String, String>? agents,
    String? connectivityCheckUrl,
    bool? echoMessages,
    bool? queueMessages,
    bool? autoConnect,
    int? realtimeRequestTimeout,
    int? disconnectedRetryTimeout,
    int? suspendedRetryTimeout,
  }) {
    return ClientOptions._(
      key: key ?? this.key,
      authUrl: authUrl ?? this.authUrl,
      authMethod: authMethod ?? this.authMethod,
      authHeaders: authHeaders ?? this.authHeaders,
      authParams: authParams ?? this.authParams,
      authCallback: authCallback ?? this.authCallback,
      tokenDetails: tokenDetails ?? this.tokenDetails,
      token: token ?? this.token,
      queryTime: queryTime ?? this.queryTime,
      useTokenAuth: useTokenAuth ?? this.useTokenAuth,
      clientId: clientId ?? this.clientId,
      logLevel: logLevel ?? this.logLevel,
      tls: tls ?? this.tls,
      endpoint: endpoint ?? this.endpoint,
      restHost: restHost ?? this.restHost,
      realtimeHost: realtimeHost ?? this.realtimeHost,
      port: port ?? this.port,
      tlsPort: tlsPort ?? this.tlsPort,
      environment: environment ?? this.environment,
      fallbackHosts: fallbackHosts ?? this.fallbackHosts,
      fallbackHostsUseDefault:
          fallbackHostsUseDefault ?? this.fallbackHostsUseDefault,
      httpMaxRetryCount: httpMaxRetryCount ?? this.httpMaxRetryCount,
      httpOpenTimeout: httpOpenTimeout ?? this.httpOpenTimeout,
      httpRequestTimeout: httpRequestTimeout ?? this.httpRequestTimeout,
      fallbackRetryTimeout: fallbackRetryTimeout ?? this.fallbackRetryTimeout,
      useBinaryProtocol: useBinaryProtocol ?? this.useBinaryProtocol,
      idempotentRestPublishing:
          idempotentRestPublishing ?? this.idempotentRestPublishing,
      addRequestIds: addRequestIds ?? this.addRequestIds,
      maxMessageSize: maxMessageSize ?? this.maxMessageSize,
      defaultTokenParams: defaultTokenParams ?? this.defaultTokenParams,
      transportParams: transportParams ?? this.transportParams,
      agents: agents ?? this.agents,
      connectivityCheckUrl: connectivityCheckUrl ?? this.connectivityCheckUrl,
      echoMessages: echoMessages ?? this.echoMessages,
      queueMessages: queueMessages ?? this.queueMessages,
      autoConnect: autoConnect ?? this.autoConnect,
      realtimeRequestTimeout:
          realtimeRequestTimeout ?? this.realtimeRequestTimeout,
      disconnectedRetryTimeout:
          disconnectedRetryTimeout ?? this.disconnectedRetryTimeout,
      suspendedRetryTimeout:
          suspendedRetryTimeout ?? this.suspendedRetryTimeout,
    );
  }

  @override
  String toString() {
    return 'ClientOptions(clientId=$clientId, tls=$tls, '
        'restHost=$effectiveRestHost)';
  }
}
