import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'message_extras.dart';

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
  });

  /// Creates a Message from a JSON map, decoding data based on encoding.
  factory Message.fromMap(Map<String, dynamic> map) {
    final rawData = map['data'];
    final encoding = map['encoding'] as String?;

    // Decode data based on encoding
    final decodedData = _decodeData(rawData, encoding);

    return Message(
      id: map['id'] as String?,
      name: map['name'] as String?,
      data: decodedData,
      clientId: map['clientId'] as String?,
      connectionId: map['connectionId'] as String?,
      timestamp: map['timestamp'] as int?,
      encoding: null, // Encoding is consumed during decode
      extras: map['extras'] != null
          ? MessageExtras.fromMap(map['extras'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Decodes data based on encoding string.
  /// Encoding can be a single encoding or compound (e.g., 'json/base64').
  static Object? _decodeData(Object? data, String? encoding) {
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
      result = _decodeSingle(result, enc);
    }

    return result;
  }

  /// Decodes data with a single encoding.
  static Object? _decodeSingle(Object? data, String encoding) {
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
    return jsonArray
        .cast<Map<String, dynamic>>()
        .map(Message.fromMap)
        .toList();
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
        // JSON-encodable objects
        map['data'] = data;
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
