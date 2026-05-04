import 'package:meta/meta.dart';

import 'annotation_action.dart';
import 'message_extras.dart';

/// Represents an individual annotation event on a message.
///
/// Spec: TAN1, TAN2
@immutable
class Annotation {
  /// Creates an Annotation.
  const Annotation({
    this.id,
    this.action,
    this.clientId,
    this.name,
    this.count,
    this.data,
    this.encoding,
    this.timestamp,
    this.serial,
    this.messageSerial,
    this.type,
    this.extras,
  });

  /// Creates an Annotation from a JSON map.
  ///
  /// The `action` field is deserialized from its numeric wire value
  /// to an [AnnotationAction] enum.
  factory Annotation.fromMap(Map<String, dynamic> map) {
    AnnotationAction? action;
    final rawAction = map['action'];
    if (rawAction is int) {
      action = AnnotationActionExtension.fromInt(rawAction);
    }

    return Annotation(
      id: map['id'] as String?,
      action: action,
      clientId: map['clientId'] as String?,
      name: map['name'] as String?,
      count: map['count'] as int?,
      data: map['data'],
      encoding: map['encoding'] as String?,
      timestamp: map['timestamp'] as int?,
      serial: map['serial'] as String?,
      messageSerial: map['messageSerial'] as String?,
      type: map['type'] as String?,
      extras: map['extras'] != null
          ? MessageExtras.fromMap(map['extras'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Unique annotation ID.
  ///
  /// Spec: TAN2a
  final String? id;

  /// The action type of the annotation.
  ///
  /// Spec: TAN2b
  final AnnotationAction? action;

  /// Client ID of the annotation publisher.
  ///
  /// Spec: TAN2c
  final String? clientId;

  /// The annotation name (e.g. "like", "heart").
  ///
  /// Spec: TAN2d
  final String? name;

  /// The aggregated count for this annotation type/name.
  ///
  /// Spec: TAN2e
  final int? count;

  /// The annotation payload data.
  ///
  /// Spec: TAN2f
  final Object? data;

  /// Encoding for the data field.
  ///
  /// Spec: TAN2g
  final String? encoding;

  /// Timestamp when the annotation was created, in milliseconds since epoch.
  ///
  /// Spec: TAN2h
  final int? timestamp;

  /// The unique serial of this annotation.
  ///
  /// Spec: TAN2i
  final String? serial;

  /// The serial of the message this annotation is associated with.
  ///
  /// Spec: TAN2j
  final String? messageSerial;

  /// The annotation type (e.g. "com.ably.reactions").
  ///
  /// Spec: TAN2k
  final String? type;

  /// Additional metadata.
  ///
  /// Spec: TAN2l
  final MessageExtras? extras;

  /// Converts this Annotation to a JSON map for transmission.
  ///
  /// The `action` field is serialized as its numeric wire value.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (id != null) map['id'] = id;
    if (action != null) map['action'] = action!.toInt();
    if (clientId != null) map['clientId'] = clientId;
    if (name != null) map['name'] = name;
    if (count != null) map['count'] = count;
    if (data != null) map['data'] = data;
    if (encoding != null) map['encoding'] = encoding;
    if (timestamp != null) map['timestamp'] = timestamp;
    if (serial != null) map['serial'] = serial;
    if (messageSerial != null) map['messageSerial'] = messageSerial;
    if (type != null) map['type'] = type;
    if (extras != null) map['extras'] = extras!.toMap();
    return map;
  }
}
