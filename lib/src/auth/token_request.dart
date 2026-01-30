import 'package:meta/meta.dart';

/// A signed token request that can be exchanged for a token.
///
/// Spec: TE
@immutable
class TokenRequest {
  /// Creates a TokenRequest instance.
  const TokenRequest({
    this.keyName,
    this.nonce,
    this.mac,
    this.capability,
    this.clientId,
    this.timestamp,
    this.ttl,
  });

  /// Creates a TokenRequest from a JSON map.
  factory TokenRequest.fromMap(Map<String, dynamic> map) {
    return TokenRequest(
      keyName: map['keyName'] as String?,
      nonce: map['nonce'] as String?,
      mac: map['mac'] as String?,
      capability: map['capability'] as String?,
      clientId: map['clientId'] as String?,
      timestamp: map['timestamp'] as int?,
      ttl: map['ttl'] as int?,
    );
  }

  /// Creates a TokenRequest from a JSON map.
  ///
  /// Alias for [fromMap].
  factory TokenRequest.fromJson(Map<String, dynamic> json) =
      TokenRequest.fromMap;

  /// The key name (public portion of the API key).
  ///
  /// Spec: TE1
  final String? keyName;

  /// A cryptographically secure random string of at least 16 characters.
  ///
  /// Spec: TE6
  final String? nonce;

  /// The Message Authentication Code for this request.
  final String? mac;

  /// JSON-encoded capability for this token request.
  ///
  /// Spec: TE3
  final String? capability;

  /// The clientId for this token request.
  ///
  /// Spec: TE4
  final String? clientId;

  /// The timestamp of this request, in milliseconds since Unix epoch.
  ///
  /// Spec: TE5
  final int? timestamp;

  /// Time to live for the requested token, in milliseconds.
  ///
  /// Spec: TE2
  final int? ttl;

  /// Returns the timestamp as a DateTime, if set.
  DateTime? get timestampAsDateTime => timestamp != null
      ? DateTime.fromMillisecondsSinceEpoch(timestamp!)
      : null;

  /// Converts this TokenRequest to a JSON map.
  Map<String, dynamic> toMap() {
    return {
      if (keyName != null) 'keyName': keyName,
      if (nonce != null) 'nonce': nonce,
      if (mac != null) 'mac': mac,
      if (capability != null) 'capability': capability,
      if (clientId != null) 'clientId': clientId,
      if (timestamp != null) 'timestamp': timestamp,
      if (ttl != null) 'ttl': ttl,
    };
  }

  /// Converts this TokenRequest to a JSON map.
  ///
  /// Alias for [toMap].
  Map<String, dynamic> toJson() => toMap();

  @override
  String toString() {
    return 'TokenRequest(keyName=$keyName, clientId=$clientId, ttl=$ttl)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TokenRequest &&
        other.keyName == keyName &&
        other.nonce == nonce &&
        other.mac == mac &&
        other.capability == capability &&
        other.clientId == clientId &&
        other.timestamp == timestamp &&
        other.ttl == ttl;
  }

  @override
  int get hashCode {
    return Object.hash(
      keyName,
      nonce,
      mac,
      capability,
      clientId,
      timestamp,
      ttl,
    );
  }
}
