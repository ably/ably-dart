import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'message_action.dart';
import 'message_annotations.dart';
import 'message_extras.dart';
import 'message_version.dart';

/// A message sent to or received from Ably.
///
/// Spec: TM
@immutable
class Message {
  /// Creates a Message instance.
  const Message({
    this.id,
    this.name,
    this.data,
    this.clientId,
    this.connectionId,
    this.timestamp,
    this.encoding,
    this.extras,
    this.action,
    this.serial,
    this.version,
    this.annotations,
  });

  /// Creates a Message from a JSON map, decoding data based on encoding.
  factory Message.fromMap(Map<String, dynamic> map) {
    final rawData = map['data'];
    final encoding = map['encoding'] as String?;

    // Decode data based on encoding
    final decodedData = decodeData(rawData, encoding);

    // Parse action from numeric wire value (TM2j)
    MessageAction? action;
    final rawAction = map['action'];
    if (rawAction is int) {
      action = MessageActionExtension.fromInt(rawAction);
    }

    // Parse serial (TM2r)
    final serial = map['serial'] as String?;
    final timestamp = map['timestamp'] as int?;

    // Parse version (TM2s) — if absent, initialize from serial/timestamp
    MessageVersion? version;
    final rawVersion = map['version'];
    if (rawVersion is Map<String, dynamic>) {
      version = MessageVersion.fromMap(rawVersion);
    } else if (serial != null || timestamp != null) {
      // TM2s1: version.serial defaults to message serial
      // TM2s2: version.timestamp defaults to message timestamp
      version = MessageVersion(
        serial: serial,
        timestamp: timestamp,
      );
    }

    // Parse annotations (TM2u) — if absent, initialize to empty
    MessageAnnotations? annotations;
    final rawAnnotations = map['annotations'];
    if (rawAnnotations is Map<String, dynamic>) {
      annotations = MessageAnnotations.fromMap(rawAnnotations);
    } else {
      annotations = const MessageAnnotations();
    }

    return Message(
      id: map['id'] as String?,
      name: map['name'] as String?,
      data: decodedData,
      clientId: map['clientId'] as String?,
      connectionId: map['connectionId'] as String?,
      timestamp: timestamp,
      encoding: null, // Encoding is consumed during decode
      extras: map['extras'] != null
          ? MessageExtras.fromMap(map['extras'] as Map<String, dynamic>)
          : null,
      action: action,
      serial: serial,
      version: version,
      annotations: annotations,
    );
  }

  /// Decodes data based on encoding string.
  /// Encoding can be a single encoding or compound (e.g., 'json/base64').
  static Object? decodeData(Object? data, String? encoding) {
    if (data == null || encoding == null || encoding.isEmpty) {
      return data;
    }

    // Split compound encodings and process in reverse order
    // e.g., 'json/base64' means: base64 was applied last, so decode base64 first
    final encodings = encoding.split('/');
    Object? result = data;

    // Process encodings in reverse order (last applied = first decoded)
    for (var i = encodings.length - 1; i >= 0; i--) {
      final enc = encodings[i].trim();
      result = decodeSingle(result, enc);
    }

    return result;
  }

  /// Decodes data with a single encoding step.
  ///
  /// Handles `base64`, `json`, and `utf-8` encodings.
  /// Returns data unchanged for unknown encodings.
  static Object? decodeSingle(Object? data, String encoding) {
    switch (encoding) {
      case 'base64':
        if (data is String) {
          return Uint8List.fromList(base64.decode(data));
        }
        return data;
      case 'json':
        if (data is String) {
          return json.decode(data);
        }
        // Handle bytes from previous base64 decode
        if (data is Uint8List) {
          return json.decode(utf8.decode(data));
        }
        return data;
      case 'utf-8':
        if (data is Uint8List) {
          return utf8.decode(data);
        }
        return data;
      default:
        // Unknown encoding, return as-is
        return data;
    }
  }

  /// Creates a Message from a JSON map.
  ///
  /// Alias for [fromMap].
  factory Message.fromJson(Map<String, dynamic> json) = Message.fromMap;

  /// Creates a list of Messages from a JSON array.
  static List<Message> fromEncodedArray(List<dynamic> jsonArray) {
    return jsonArray.cast<Map<String, dynamic>>().map(Message.fromMap).toList();
  }

  /// Unique message ID assigned by Ably.
  ///
  /// Spec: TM2a
  final String? id;

  /// Event name for this message.
  ///
  /// Spec: TM2b
  final String? name;

  /// Message payload.
  ///
  /// Can be String, Map, List, or Uint8List.
  ///
  /// Spec: TM2c
  final Object? data;

  /// ClientId of the publisher.
  ///
  /// Spec: TM2d
  final String? clientId;

  /// Connection ID of the publisher.
  ///
  /// Spec: TM2e
  final String? connectionId;

  /// Timestamp when the message was received by Ably, in milliseconds
  /// since Unix epoch.
  ///
  /// Spec: TM2f
  final int? timestamp;

  /// Any remaining encoding transformations to be applied.
  ///
  /// Spec: TM2g
  final String? encoding;

  /// Message extras containing metadata.
  ///
  /// Spec: TM2h
  final MessageExtras? extras;

  /// The action type of the message.
  ///
  /// Spec: TM2j
  final MessageAction? action;

  /// An opaque string that uniquely identifies the message.
  ///
  /// Spec: TM2r
  final String? serial;

  /// Information about the latest version of the message.
  ///
  /// Spec: TM2s
  final MessageVersion? version;

  /// Annotations associated with this message.
  ///
  /// Spec: TM2u
  final MessageAnnotations? annotations;

  /// Returns the timestamp as a DateTime, if set.
  DateTime? get timestampAsDateTime => timestamp != null
      ? DateTime.fromMillisecondsSinceEpoch(timestamp!)
      : null;

  /// Converts this Message to a JSON map for transmission.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    if (id != null) map['id'] = id;
    if (name != null) map['name'] = name;
    if (data != null) {
      if (data is Uint8List) {
        // Binary data needs base64 encoding for JSON
        map['data'] = base64.encode(data as Uint8List);
        map['encoding'] = _combineEncodings('base64', encoding);
      } else if (data is Map || data is List) {
        // JSON-encodable objects — encode to JSON string for wire format
        map['data'] = json.encode(data);
        map['encoding'] = _combineEncodings('json', encoding);
      } else {
        map['data'] = data;
        if (encoding != null) map['encoding'] = encoding;
      }
    }
    if (clientId != null) map['clientId'] = clientId;
    if (connectionId != null) map['connectionId'] = connectionId;
    if (timestamp != null) map['timestamp'] = timestamp;
    if (extras != null) map['extras'] = extras!.toMap();

    // Mutable message fields
    if (action != null) map['action'] = action!.toInt();
    if (serial != null) map['serial'] = serial;
    if (version != null) map['version'] = version!.toMap();
    // annotations is read-only from wire, not sent by client

    return map;
  }

  String? _combineEncodings(String newEncoding, String? existingEncoding) {
    if (existingEncoding == null || existingEncoding.isEmpty) {
      return newEncoding;
    }
    return '$existingEncoding/$newEncoding';
  }

  /// Converts this Message to a JSON map.
  ///
  /// Alias for [toMap].
  Map<String, dynamic> toJson() => toMap();

  /// Creates a copy of this Message with the given fields replaced.
  Message copyWith({
    String? id,
    String? name,
    Object? data,
    String? clientId,
    String? connectionId,
    int? timestamp,
    String? encoding,
    MessageExtras? extras,
    MessageAction? action,
    String? serial,
    MessageVersion? version,
    MessageAnnotations? annotations,
  }) {
    return Message(
      id: id ?? this.id,
      name: name ?? this.name,
      data: data ?? this.data,
      clientId: clientId ?? this.clientId,
      connectionId: connectionId ?? this.connectionId,
      timestamp: timestamp ?? this.timestamp,
      encoding: encoding ?? this.encoding,
      extras: extras ?? this.extras,
      action: action ?? this.action,
      serial: serial ?? this.serial,
      version: version ?? this.version,
      annotations: annotations ?? this.annotations,
    );
  }

  @override
  String toString() {
    return 'Message(id=$id, name=$name, data=$data, clientId=$clientId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message &&
        other.id == id &&
        other.name == name &&
        other.clientId == clientId &&
        other.connectionId == connectionId &&
        other.timestamp == timestamp &&
        other.encoding == encoding;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, clientId, connectionId, timestamp, encoding);
  }
}
