import 'package:meta/meta.dart';

/// Defines the properties of an Ably Token.
///
/// Spec: TK
@immutable
class TokenParams {
  /// Creates a TokenParams instance.
  const TokenParams({
    this.capability,
    this.clientId,
    this.nonce,
    this.timestamp,
    this.ttl,
  });

  /// Creates a TokenParams from a JSON map.
  factory TokenParams.fromMap(Map<String, dynamic> map) {
    return TokenParams(
      capability: map['capability'] as String?,
      clientId: map['clientId'] as String?,
      nonce: map['nonce'] as String?,
      timestamp: map['timestamp'] as int?,
      ttl: map['ttl'] as int?,
    );
  }

  /// Creates a TokenParams from a JSON map.
  ///
  /// Alias for [fromMap].
  factory TokenParams.fromJson(Map<String, dynamic> json) =
      TokenParams.fromMap;

  /// JSON-encoded capability for this token.
  ///
  /// If not specified, defaults to the full set of capabilities granted
  /// to the current key.
  final String? capability;

  /// The clientId to be bound to this token.
  ///
  /// If set, the token can only be used by clients with this clientId.
  final String? clientId;

  /// A cryptographically secure random string of at least 16 characters.
  ///
  /// Used to ensure idempotency of token requests.
  final String? nonce;

  /// The timestamp of this request, in milliseconds since Unix epoch.
  ///
  /// Used to prevent replay attacks.
  ///
  /// Spec: TK4
  final int? timestamp;

  /// Time to live for this token, in milliseconds.
  ///
  /// Defaults to 60 minutes.
  ///
  /// Spec: TK1
  final int? ttl;

  /// Returns the timestamp as a DateTime, if set.
  DateTime? get timestampAsDateTime => timestamp != null
      ? DateTime.fromMillisecondsSinceEpoch(timestamp!)
      : null;

  /// Converts this TokenParams to a JSON map.
  Map<String, dynamic> toMap() {
    return {
      if (capability != null) 'capability': capability,
      if (clientId != null) 'clientId': clientId,
      if (nonce != null) 'nonce': nonce,
      if (timestamp != null) 'timestamp': timestamp,
      if (ttl != null) 'ttl': ttl,
    };
  }

  /// Converts this TokenParams to a JSON map.
  ///
  /// Alias for [toMap].
  Map<String, dynamic> toJson() => toMap();

  /// Converts this TokenParams to query parameters for URL encoding.
  Map<String, String> toQueryParams() {
    final result = <String, String>{};
    if (capability != null) result['capability'] = capability!;
    if (clientId != null) result['clientId'] = clientId!;
    if (nonce != null) result['nonce'] = nonce!;
    if (timestamp != null) result['timestamp'] = timestamp.toString();
    if (ttl != null) result['ttl'] = ttl.toString();
    return result;
  }

  /// Creates a copy of this TokenParams with the given fields replaced.
  TokenParams copyWith({
    String? capability,
    String? clientId,
    String? nonce,
    int? timestamp,
    int? ttl,
  }) {
    return TokenParams(
      capability: capability ?? this.capability,
      clientId: clientId ?? this.clientId,
      nonce: nonce ?? this.nonce,
      timestamp: timestamp ?? this.timestamp,
      ttl: ttl ?? this.ttl,
    );
  }

  @override
  String toString() {
    return 'TokenParams(clientId=$clientId, ttl=$ttl, capability=$capability)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TokenParams &&
        other.capability == capability &&
        other.clientId == clientId &&
        other.nonce == nonce &&
        other.timestamp == timestamp &&
        other.ttl == ttl;
  }

  @override
  int get hashCode {
    return Object.hash(capability, clientId, nonce, timestamp, ttl);
  }
}
