import 'package:meta/meta.dart';

import '../presence/presence_action.dart';
import 'message.dart';
import 'message_extras.dart';

/// A presence message indicating a presence state change.
@immutable
class PresenceMessage {
  /// Creates a PresenceMessage instance.
  const PresenceMessage({
    this.id,
    this.action,
    this.clientId,
    this.connectionId,
    this.data,
    this.encoding,
    this.extras,
    this.timestamp,
  });

  /// Creates a PresenceMessage from a JSON map.
  ///
  /// Accepts action as either an int (wire protocol) or a string (legacy).
  factory PresenceMessage.fromMap(Map<String, dynamic> map) {
    PresenceAction? action;
    if (map['action'] != null) {
      final raw = map['action'];
      if (raw is int) {
        action = PresenceActionExtension.fromInt(raw);
      } else if (raw is String) {
        action = PresenceActionExtension.fromAblyString(raw);
      }
    }
    final encoding = map['encoding'] as String?;
    final rawData = map['data'];
    final decodeResult = _decodePresenceData(rawData, encoding);
    return PresenceMessage(
      id: map['id'] as String?,
      action: action,
      clientId: map['clientId'] as String?,
      connectionId: map['connectionId'] as String?,
      data: decodeResult.data,
      encoding: decodeResult.remainingEncoding,
      extras: map['extras'] != null
          ? MessageExtras.fromMap(map['extras'] as Map<String, dynamic>)
          : null,
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : null,
    );
  }

  /// Creates a list of PresenceMessages from a JSON array.
  static List<PresenceMessage> fromEncodedArray(List<dynamic> jsonArray) {
    return jsonArray
        .cast<Map<String, dynamic>>()
        .map(PresenceMessage.fromMap)
        .toList();
  }

  /// Unique message ID.
  final String? id;

  /// The presence action type.
  final PresenceAction? action;

  /// The clientId of the member.
  final String? clientId;

  /// The connection ID of the member.
  final String? connectionId;

  /// Optional presence data payload.
  final Object? data;

  /// Any remaining encoding transformations.
  final String? encoding;

  /// Message extras containing metadata.
  final MessageExtras? extras;

  /// Timestamp when the message was received by Ably.
  final DateTime? timestamp;

  /// Unique identifier for this member.
  String get memberKey => '$connectionId:$clientId';

  /// Converts this PresenceMessage to a map for wire transmission.
  Map<String, dynamic> toMap({bool useBinaryProtocol = false}) {
    final map = <String, dynamic>{
      if (id != null) 'id': id,
      if (action != null) 'action': action!.toInt(),
      if (clientId != null) 'clientId': clientId,
      if (connectionId != null) 'connectionId': connectionId,
      if (extras != null) 'extras': extras!.toMap(),
      if (timestamp != null) 'timestamp': timestamp!.millisecondsSinceEpoch,
    };
    if (data != null) {
      Message.encodeDataInto(
        map,
        data!,
        encoding,
        useBinaryProtocol: useBinaryProtocol,
      );
    }
    return map;
  }

  static _DecodeResult _decodePresenceData(Object? data, String? encoding) {
    if (data == null || encoding == null || encoding.isEmpty) {
      return _DecodeResult(data, encoding);
    }
    final encodings = encoding.split('/');
    Object? result = data;
    for (var i = encodings.length - 1; i >= 0; i--) {
      final enc = encodings[i].trim();
      if (enc == 'json' || enc == 'base64' || enc == 'utf-8') {
        result = Message.decodeSingle(result, enc);
      } else {
        final remaining = encodings.sublist(0, i + 1).join('/');
        return _DecodeResult(result, remaining);
      }
    }
    return _DecodeResult(result, null);
  }

  /// Creates a copy of this PresenceMessage with the given fields replaced.
  ///
  /// Set [clearId] to true to explicitly set id to null (e.g. for
  /// synthesized LEAVE events per RTP19).
  PresenceMessage copyWith({
    PresenceAction? action,
    DateTime? timestamp,
    bool clearId = false,
  }) =>
      PresenceMessage(
        id: clearId ? null : id,
        action: action ?? this.action,
        clientId: clientId,
        connectionId: connectionId,
        data: data,
        encoding: encoding,
        extras: extras,
        timestamp: timestamp ?? this.timestamp,
      );

  @override
  String toString() {
    return 'PresenceMessage(action=$action, clientId=$clientId, data=$data)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PresenceMessage &&
        other.id == id &&
        other.action == action &&
        other.clientId == clientId &&
        other.connectionId == connectionId;
  }

  @override
  int get hashCode => Object.hash(id, action, clientId, connectionId);
}

class _DecodeResult {
  _DecodeResult(this.data, this.remainingEncoding);
  final Object? data;
  final String? remainingEncoding;
}
