import 'package:clock/clock.dart';
import 'package:meta/meta.dart';

/// Contains the details of an Ably Token.
///
/// Spec: TD
@immutable
class TokenDetails {
  /// Creates a TokenDetails instance.
  const TokenDetails({
    this.token,
    this.expires,
    this.issued,
    this.capability,
    this.clientId,
  });

  /// Creates a TokenDetails from a JSON map.
  factory TokenDetails.fromMap(Map<String, dynamic> map) {
    return TokenDetails(
      token: map['token'] as String?,
      expires: map['expires'] as int?,
      issued: map['issued'] as int?,
      capability: map['capability'] as String?,
      clientId: map['clientId'] as String?,
    );
  }

  /// Creates a TokenDetails from a JSON map.
  ///
  /// Alias for [fromMap].
  factory TokenDetails.fromJson(Map<String, dynamic> json) =
      TokenDetails.fromMap;

  /// The token string.
  final String? token;

  /// Token expiry time as milliseconds since Unix epoch.
  final int? expires;

  /// Token issue time as milliseconds since Unix epoch.
  final int? issued;

  /// JSON-encoded capabilities associated with this token.
  final String? capability;

  /// The clientId associated with this token, if any.
  final String? clientId;

  /// Returns the expiry time as a DateTime.
  DateTime? get expiresAt =>
      expires != null ? DateTime.fromMillisecondsSinceEpoch(expires!) : null;

  /// Returns the issue time as a DateTime.
  DateTime? get issuedAt =>
      issued != null ? DateTime.fromMillisecondsSinceEpoch(issued!) : null;

  /// Returns true if this token has expired.
  ///
  /// Uses the `clock` package so tests can control time.
  bool get isExpired {
    if (expires == null) return false;
    return clock.now().millisecondsSinceEpoch >= expires!;
  }

  /// Converts this TokenDetails to a JSON map.
  Map<String, dynamic> toMap() {
    return {
      if (token != null) 'token': token,
      if (expires != null) 'expires': expires,
      if (issued != null) 'issued': issued,
      if (capability != null) 'capability': capability,
      if (clientId != null) 'clientId': clientId,
    };
  }

  /// Converts this TokenDetails to a JSON map.
  ///
  /// Alias for [toMap].
  Map<String, dynamic> toJson() => toMap();

  @override
  String toString() {
    return 'TokenDetails(token=${token?.substring(0, 10)}..., '
        'expires=$expires, clientId=$clientId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TokenDetails &&
        other.token == token &&
        other.expires == expires &&
        other.issued == issued &&
        other.capability == capability &&
        other.clientId == clientId;
  }

  @override
  int get hashCode {
    return Object.hash(token, expires, issued, capability, clientId);
  }
}
