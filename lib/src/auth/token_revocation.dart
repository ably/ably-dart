import 'package:meta/meta.dart';

import '../error/error_info.dart';

/// Describes which tokens should be affected by a token revocation request.
///
/// Spec: TRT1, TRT2
@immutable
class TokenRevocationTargetSpecifier {
  /// Creates a target specifier.
  const TokenRevocationTargetSpecifier({
    required this.type,
    required this.value,
  });

  /// The type of token revocation target (e.g. "clientId", "revocationKey").
  ///
  /// Spec: TRT2a
  final String type;

  /// The value of the token revocation target.
  ///
  /// Spec: TRT2b
  final String value;

  /// Returns the target string in `type:value` format.
  ///
  /// Spec: RSA17b
  String toTargetString() => '$type:$value';
}

/// Options for a token revocation request.
@immutable
class RevokeTokensOptions {
  /// Creates revocation options.
  const RevokeTokensOptions({
    this.issuedBefore,
    this.allowReauthMargin,
  });

  /// Optional timestamp (ms since epoch). Only tokens issued before this
  /// time are revoked.
  ///
  /// Spec: RSA17e
  final int? issuedBefore;

  /// If true, delays revocation by ~30 seconds to allow token renewal.
  ///
  /// Spec: RSA17f
  final bool? allowReauthMargin;
}

/// Response from a token revocation request.
///
/// Spec: RSA17c, BAR2
@immutable
class TokenRevocationResponse {
  /// Creates a token revocation response.
  const TokenRevocationResponse({
    required this.successCount,
    required this.failureCount,
    required this.results,
  });

  /// Creates a response from a server JSON map with explicit counts.
  factory TokenRevocationResponse.fromMap(Map<String, dynamic> map) {
    final resultsList = (map['results'] as List?) ?? [];
    final results = resultsList
        .cast<Map<String, dynamic>>()
        .map(TokenRevocationResult.fromMap)
        .toList();

    return TokenRevocationResponse(
      successCount: map['successCount'] as int? ?? 0,
      failureCount: map['failureCount'] as int? ?? 0,
      results: results,
    );
  }

  /// The number of successful revocations.
  ///
  /// Spec: BAR2a
  final int successCount;

  /// The number of unsuccessful revocations.
  ///
  /// Spec: BAR2b
  final int failureCount;

  /// The per-target results.
  ///
  /// Spec: BAR2c
  final List<TokenRevocationResult> results;
}

/// Base class for per-target token revocation results.
@immutable
sealed class TokenRevocationResult {
  const TokenRevocationResult({required this.target});

  /// The target specifier string (e.g. "clientId:alice").
  final String target;

  /// Creates a result from a server JSON map.
  factory TokenRevocationResult.fromMap(Map<String, dynamic> map) {
    final target = map['target'] as String;

    if (map.containsKey('error')) {
      return TokenRevocationFailureResult(
        target: target,
        error: ErrorInfo.fromMap(map['error'] as Map<String, dynamic>),
      );
    }

    return TokenRevocationSuccessResult(
      target: target,
      issuedBefore: map['issuedBefore'] as int,
      appliesAt: map['appliesAt'] as int,
    );
  }
}

/// Result of a successful token revocation for a single target.
///
/// Spec: TRS1, TRS2
@immutable
class TokenRevocationSuccessResult extends TokenRevocationResult {
  /// Creates a success result.
  const TokenRevocationSuccessResult({
    required super.target,
    required this.issuedBefore,
    required this.appliesAt,
  });

  /// Timestamp for which previously issued tokens are revoked.
  ///
  /// Spec: TRS2c
  final int issuedBefore;

  /// Timestamp at which the revocation takes effect.
  ///
  /// Spec: TRS2b
  final int appliesAt;
}

/// Result of an unsuccessful token revocation for a single target.
///
/// Spec: TRF1, TRF2
@immutable
class TokenRevocationFailureResult extends TokenRevocationResult {
  /// Creates a failure result.
  const TokenRevocationFailureResult({
    required super.target,
    required this.error,
  });

  /// The reason the revocation failed.
  ///
  /// Spec: TRF2b
  final ErrorInfo error;
}
