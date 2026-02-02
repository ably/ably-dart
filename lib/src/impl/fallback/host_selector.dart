import 'dart:math';

import '../../auth/client_options.dart';
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
    Random? random,
  })  : _options = options,
        _random = random ?? Random();

  final ClientOptions _options;
  final Random _random;

  // Track fallback host failures
  DateTime? _fallbackHostsUnavailableSince;
  final Set<String> _failedHosts = {};

  /// Gets the ordered list of hosts to try.
  ///
  /// Returns primary host first, followed by shuffled fallback hosts
  /// (excluding recently failed hosts).
  ///
  /// The number of fallback hosts is limited by [ClientOptions.httpMaxRetryCount].
  ///
  /// Spec: RTN17i - Always prefer primary domain first
  List<String> getHostsToTry({
    required String primaryHost,
    List<String>? fallbackHosts,
  }) {
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
        if (_options.realtimeHost != null ||
            _options.restHost != null ||
            (_options.endpoint != null && _options.endpoint!.contains('.'))) {
          // Custom host - no fallbacks (REC2c2, REC2c6)
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
      final elapsed =
          DateTime.now().difference(_fallbackHostsUnavailableSince!);
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

    return hosts;
  }

  /// Marks a host as failed.
  ///
  /// Failed hosts will be excluded from future host selection until
  /// the failure tracking is cleared.
  void markHostAsFailed(String host) {
    if (!_failedHosts.contains(host)) {
      _failedHosts.add(host);
    }

    // If all fallback hosts have failed, mark the timestamp
    final fallbacks = _options.fallbackHosts ?? defaultFallbackHosts;
    if (_failedHosts.length >= fallbacks.length + 1) {
      // +1 for primary host
      _fallbackHostsUnavailableSince = DateTime.now();
    }
  }

  /// Clears failure tracking after successful connection to a fallback host.
  ///
  /// This should be called when a fallback host successfully handles a request
  /// or establishes a connection.
  ///
  /// Spec: RSC15f - Clear failure tracking on success
  void clearFailureTracking() {
    _failedHosts.clear();
    _fallbackHostsUnavailableSince = null;
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
