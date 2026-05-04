import 'package:meta/meta.dart';

/// Contains details about the current version of a message.
///
/// Spec: TM2s, TM2s1–TM2s5
@immutable
class MessageVersion {
  /// Creates a MessageVersion.
  const MessageVersion({
    this.serial,
    this.timestamp,
    this.clientId,
    this.description,
    this.metadata,
  });

  /// Creates a MessageVersion from a JSON map.
  factory MessageVersion.fromMap(Map<String, dynamic> map) {
    return MessageVersion(
      serial: map['serial'] as String?,
      timestamp: map['timestamp'] as int?,
      clientId: map['clientId'] as String?,
      description: map['description'] as String?,
      metadata: map['metadata'] != null
          ? Map<String, String>.from(map['metadata'] as Map)
          : null,
    );
  }

  /// A unique identifier for the version of the message.
  ///
  /// Spec: TM2s1
  final String? serial;

  /// Timestamp when this version was created, in milliseconds since epoch.
  ///
  /// Spec: TM2s2
  final int? timestamp;

  /// Client ID of the user who created this version.
  ///
  /// Spec: TM2s3
  final String? clientId;

  /// A description of the operation that created this version.
  ///
  /// Spec: TM2s4
  final String? description;

  /// Arbitrary key-value metadata associated with this version.
  ///
  /// Spec: TM2s5
  final Map<String, String>? metadata;

  /// Converts this MessageVersion to a JSON map.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (serial != null) map['serial'] = serial;
    if (timestamp != null) map['timestamp'] = timestamp;
    if (clientId != null) map['clientId'] = clientId;
    if (description != null) map['description'] = description;
    if (metadata != null) map['metadata'] = metadata;
    return map;
  }
}
