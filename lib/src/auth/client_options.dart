import 'package:meta/meta.dart';

import '../logging/log_level.dart';
import 'auth_options.dart';
import 'token_details.dart';
import 'token_params.dart';

/// Configuration options for the Ably REST client.
///
/// Extends [AuthOptions] with client-specific configuration.
///
/// Spec: TO, RSC1
@immutable
class ClientOptions extends AuthOptions {
  /// Creates a ClientOptions instance.
  ///
  /// Throws [ArgumentError] if both [restHost] and [environment] are set.
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
    String? restHost,
    int? port,
    int? tlsPort,
    String? environment,
    List<String>? fallbackHosts,
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
  }) {
    // Validate conflicting options (TO3k)
    if (restHost != null && environment != null) {
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
      restHost: restHost,
      port: port,
      tlsPort: tlsPort,
      environment: environment,
      fallbackHosts: fallbackHosts,
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
    this.restHost,
    this.port,
    this.tlsPort,
    this.environment,
    this.fallbackHosts,
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

  /// Custom REST host.
  final String? restHost;

  /// Custom non-TLS port.
  final int? port;

  /// Custom TLS port.
  final int? tlsPort;

  /// Environment (e.g., 'sandbox').
  final String? environment;

  /// List of fallback hosts to use if the primary fails.
  final List<String>? fallbackHosts;

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

  /// Returns the effective REST host.
  String get effectiveRestHost {
    if (restHost != null) return restHost!;
    if (environment != null) return '$environment-rest.ably.io';
    return 'rest.ably.io';
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
    String? restHost,
    int? port,
    int? tlsPort,
    String? environment,
    List<String>? fallbackHosts,
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
      restHost: restHost ?? this.restHost,
      port: port ?? this.port,
      tlsPort: tlsPort ?? this.tlsPort,
      environment: environment ?? this.environment,
      fallbackHosts: fallbackHosts ?? this.fallbackHosts,
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
    );
  }

  @override
  String toString() {
    return 'ClientOptions(clientId=$clientId, tls=$tls, '
        'restHost=$effectiveRestHost)';
  }
}
