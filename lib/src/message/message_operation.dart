import 'package:meta/meta.dart';

/// Contains metadata about a message update, delete, or append operation.
///
/// Spec: MOP2a–c
@immutable
class MessageOperation {
  /// Creates a MessageOperation.
  const MessageOperation({
    this.clientId,
    this.description,
    this.metadata,
  });

  /// Optional identifier of the client performing the operation.
  ///
  /// Spec: MOP2a
  final String? clientId;

  /// Optional description of the operation.
  ///
  /// Spec: MOP2b
  final String? description;

  /// Optional arbitrary key-value metadata.
  ///
  /// Spec: MOP2c
  final Map<String, String>? metadata;

  /// Converts this MessageOperation to a JSON map.
  ///
  /// Only includes non-null fields.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (clientId != null) map['clientId'] = clientId;
    if (description != null) map['description'] = description;
    if (metadata != null) map['metadata'] = metadata;
    return map;
  }
}
