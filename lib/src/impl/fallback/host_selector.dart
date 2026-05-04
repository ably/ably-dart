import 'dart:math';

import 'package:clock/clock.dart';

import '../../auth/client_options.dart';
import '../../logging/log_level.dart';
import '../../logging/logger.dart';
import 'constants.dart';

/// Manages host selection for fallback behavior.
///
/// This class encapsulates the logic for determining which hosts to try
/// when making requests or connections, including fallback host selection
/// with random shuffling and failure tracking.
///
/// Spec: RTN17, RSC15
class HostSelector {
  HostSelector({
    required ClientOptions options,
    required Logger logger,
    Random? random,
  })  : _options = options,
        _logger = logger,
        _random = random ?? Random();

  final ClientOptions _options;
  final Logger _logger;
  final Random _random;

  // Track fallback host failures
  DateTime? _fallbackHostsUnavailableSince;
  final Set<String> _failedHosts = {};

  // RSC15f: Cached preferred fallback host
  String? _preferredHost;
  DateTime? _preferredHostSetAt;
  bool _preferredHostExpired = false;

  /// Gets the ordered list of hosts to try.
  ///
  /// If a preferred fallback host is cached (RSC15f), it is returned as the
  /// only host to try (replacing the primary host). The cache expires after
  /// [ClientOptions.fallbackRetryTimeout] milliseconds.
  ///
  /// Otherwise returns primary host first, followed by shuffled fallback hosts
  /// (excluding recently failed hosts).
  ///
  /// The number of fallback hosts is limited by [ClientOptions.httpMaxRetryCount].
  ///
  /// Spec: RTN17i - Always prefer primary domain first
  /// Spec: RSC15f - Cache preferred fallback host
  List<String> getHostsToTry({
    required String primaryHost,
    List<String>? fallbackHosts,
  }) {
    // RSC15f: If we have a cached preferred host, use it
    if (_preferredHost != null && _preferredHostSetAt != null) {
      final elapsed = clock.now().difference(_preferredHostSetAt!);
      if (elapsed.inMilliseconds < _options.fallbackRetryTimeout) {
        return [_preferredHost!];
      }
      // Preferred host cache expired - mark as expired so late in-flight
      // successes don't resurrect it
      _preferredHost = null;
      _preferredHostSetAt = null;
      _preferredHostExpired = true;
    }

    final hosts = <String>[primaryHost];

    // Determine fallback hosts (REC2)
    // Use explicit parameter if provided
    List<String> fallbacks;
    if (fallbackHosts != null) {
      fallbacks = fallbackHosts;
    } else {
      // Use effectiveFallbackHosts from options (handles all REC2 cases)
      final effectiveFallbacks = _options.effectiveFallbackHosts;
      if (effectiveFallbacks == null) {
        // REC2c1 - use default fallbacks, or REC2c2/REC2c6 - no fallbacks
        // Check if we should use defaults or truly have no fallbacks
        if (_options.endpoint != null) {
          // Explicit hostname endpoint - no fallbacks (REC2c2)
          return hosts;
        }
        // Use default fallbacks (REC2c1)
        fallbacks = defaultFallbackHosts;
      } else {
        fallbacks = effectiveFallbacks;
      }
    }

    // RTN17g: If fallback set is empty, only try primary
    if (fallbacks.isEmpty) {
      return hosts;
    }

    // Don't use fallbacks if within fallbackRetryTimeout of failure
    if (_fallbackHostsUnavailableSince != null) {
      final elapsed = clock.now().difference(_fallbackHostsUnavailableSince!);
      if (elapsed.inMilliseconds < _options.fallbackRetryTimeout) {
        return hosts;
      }
      // Clear failure tracking after timeout expires
      _fallbackHostsUnavailableSince = null;
      _failedHosts.clear();
    }

    // RTN17j: Add fallback hosts in random order (excluding failed ones)
    final availableFallbacks =
        fallbacks.where((h) => !_failedHosts.contains(h)).toList();
    availableFallbacks.shuffle(_random);

    // Limit to httpMaxRetryCount
    final maxRetries = _options.httpMaxRetryCount;
    hosts.addAll(availableFallbacks.take(maxRetries));

    if (_logger.shouldLog(LogLevel.verbose)) {
      _logger.verbose('Host try order', {'hosts': hosts});
    }

    return hosts;
  }

  /// Marks a host as failed.
  ///
  /// Failed hosts will be excluded from future host selection until
  /// the failure tracking is cleared.
  void markHostAsFailed(String host) {
    _logger.debug('Host marked as failed', {'host': host});
    if (!_failedHosts.contains(host)) {
      _failedHosts.add(host);
    }

    // If all fallback hosts have failed, mark the timestamp
    final fallbacks = _options.fallbackHosts ?? defaultFallbackHosts;
    if (_failedHosts.length >= fallbacks.length + 1) {
      // +1 for primary host
      _fallbackHostsUnavailableSince = clock.now();
    }
  }

  /// Clears failure tracking and caches the preferred fallback host.
  ///
  /// Called when a fallback host successfully handles a request
  /// or establishes a connection. The successful fallback host is cached
  /// as the preferred host for [ClientOptions.fallbackRetryTimeout] ms.
  ///
  /// RSC15f: If the preferred host cache has already expired (e.g., a late
  /// in-flight response from a previously-cached host), do NOT re-pin the
  /// fallback host. Only set/refresh the cache if it's currently active or
  /// not yet initialized.
  ///
  /// Spec: RSC15f - Cache preferred fallback host on success
  void clearFailureTracking({String? preferredHost}) {
    _failedHosts.clear();
    _fallbackHostsUnavailableSince = null;
    if (preferredHost != null) {
      // RSC15f: Don't resurrect an expired preferred host cache.
      // A late in-flight success from a previously-cached fallback host
      // must not re-pin that host after the cache has expired.
      if (!_preferredHostExpired) {
        _preferredHost = preferredHost;
        _preferredHostSetAt = clock.now();
      }
    }
  }

  /// Whether a specific host is the primary host.
  bool isPrimaryHost(String host, String primaryHost) {
    return host == primaryHost;
  }

  /// Gets the list of failed hosts.
  ///
  /// Useful for testing and debugging.
  Set<String> get failedHosts => Set.unmodifiable(_failedHosts);

  /// Gets the timestamp when fallback hosts became unavailable.
  ///
  /// Returns null if fallbacks are currently available.
  DateTime? get fallbackHostsUnavailableSince => _fallbackHostsUnavailableSince;
}
