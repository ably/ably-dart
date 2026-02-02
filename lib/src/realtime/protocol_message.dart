import '../error/error_info.dart';

/// Protocol message actions.
enum ProtocolAction {
  heartbeat, // 0
  ack, // 1
  nack, // 2
  connect, // 3
  connected, // 4
  disconnect, // 5
  disconnected, // 6
  close, // 7
  closed, // 8
  error, // 9
  attach, // 10
  attached, // 11
  detach, // 12
  detached, // 13
  presence, // 14
  message, // 15
  sync, // 16
  auth, // 17
}

extension ProtocolActionExtension on ProtocolAction {
  /// Converts action to integer for wire protocol.
  int toInt() => index;

  /// Creates action from integer.
  static ProtocolAction fromInt(int value) {
    if (value < 0 || value >= ProtocolAction.values.length) {
      throw ArgumentError('Invalid protocol action: $value');
    }
    return ProtocolAction.values[value];
  }
}

/// Protocol message for WebSocket communication with Ably.
///
/// This represents the protocol messages sent between client and server
/// over the WebSocket transport. Messages are encoded using JSON or MessagePack.
///
/// See: https://ably.com/docs/realtime/messages
class ProtocolMessage {
  /// Creates a protocol message.
  ProtocolMessage({
    this.action,
    this.channel,
    this.channelSerial,
    this.connectionId,
    this.connectionKey,
    this.connectionDetails,
    this.error,
    this.flags,
    this.id,
    this.msgSerial,
    this.timestamp,
    this.messages,
    this.presence,
    this.auth,
  });

  /// The action this message represents.
  final ProtocolAction? action;

  /// Channel name (for channel-specific messages).
  final String? channel;

  /// Channel serial for message continuity.
  final String? channelSerial;

  /// Unique connection identifier.
  final String? connectionId;

  /// Private connection key for resume.
  final String? connectionKey;

  /// Connection details from CONNECTED message.
  final ConnectionDetails? connectionDetails;

  /// Error information (for ERROR, DISCONNECTED messages).
  final ErrorInfo? error;

  /// Bit flags for message properties.
  final int? flags;

  /// Message identifier.
  final String? id;

  /// Serial number for ordering.
  final int? msgSerial;

  /// Timestamp in milliseconds since epoch.
  final int? timestamp;

  /// Array of Message objects (for MESSAGE action).
  final List<dynamic>? messages;

  /// Array of PresenceMessage objects (for PRESENCE action).
  final List<dynamic>? presence;

  /// Auth details for AUTH action.
  final dynamic auth;

  /// Creates a ProtocolMessage from JSON.
  factory ProtocolMessage.fromJson(Map<String, dynamic> json) {
    return ProtocolMessage(
      action: json['action'] != null
          ? ProtocolActionExtension.fromInt(json['action'] as int)
          : null,
      channel: json['channel'] as String?,
      channelSerial: json['channelSerial'] as String?,
      connectionId: json['connectionId'] as String?,
      connectionKey: json['connectionKey'] as String?,
      connectionDetails: json['connectionDetails'] != null
          ? ConnectionDetails.fromJson(
              json['connectionDetails'] as Map<String, dynamic>)
          : null,
      error: json['error'] != null
          ? ErrorInfo.fromJson(json['error'] as Map<String, dynamic>)
          : null,
      flags: json['flags'] as int?,
      id: json['id'] as String?,
      msgSerial: json['msgSerial'] as int?,
      timestamp: json['timestamp'] as int?,
      messages: json['messages'] as List<dynamic>?,
      presence: json['presence'] as List<dynamic>?,
      auth: json['auth'],
    );
  }

  /// Converts this ProtocolMessage to JSON.
  Map<String, dynamic> toJson() {
    return {
      if (action != null) 'action': action!.toInt(),
      if (channel != null) 'channel': channel,
      if (channelSerial != null) 'channelSerial': channelSerial,
      if (connectionId != null) 'connectionId': connectionId,
      if (connectionKey != null) 'connectionKey': connectionKey,
      if (connectionDetails != null)
        'connectionDetails': connectionDetails!.toJson(),
      if (error != null) 'error': error!.toJson(),
      if (flags != null) 'flags': flags,
      if (id != null) 'id': id,
      if (msgSerial != null) 'msgSerial': msgSerial,
      if (timestamp != null) 'timestamp': timestamp,
      if (messages != null) 'messages': messages,
      if (presence != null) 'presence': presence,
      if (auth != null) 'auth': auth,
    };
  }

  @override
  String toString() => 'ProtocolMessage(action: $action, channel: $channel)';
}

/// Connection details from CONNECTED message (CD* specs).
class ConnectionDetails {
  /// Creates connection details.
  ConnectionDetails({
    this.clientId,
    this.connectionKey,
    this.connectionStateTtl,
    this.maxIdleInterval,
    this.maxMessageSize,
    this.maxFrameSize,
    this.maxInboundRate,
    this.serverId,
  });

  /// Client identifier from server.
  final String? clientId;

  /// Private connection key for resume.
  final String? connectionKey;

  /// Connection state TTL in milliseconds.
  final int? connectionStateTtl;

  /// Max idle interval in milliseconds before heartbeat required.
  final int? maxIdleInterval;

  /// Maximum message size in bytes.
  final int? maxMessageSize;

  /// Maximum frame size in bytes.
  final int? maxFrameSize;

  /// Maximum inbound message rate.
  final int? maxInboundRate;

  /// Server identifier.
  final String? serverId;

  /// Creates ConnectionDetails from JSON.
  factory ConnectionDetails.fromJson(Map<String, dynamic> json) {
    return ConnectionDetails(
      clientId: json['clientId'] as String?,
      connectionKey: json['connectionKey'] as String?,
      connectionStateTtl: json['connectionStateTtl'] as int?,
      maxIdleInterval: json['maxIdleInterval'] as int?,
      maxMessageSize: json['maxMessageSize'] as int?,
      maxFrameSize: json['maxFrameSize'] as int?,
      maxInboundRate: json['maxInboundRate'] as int?,
      serverId: json['serverId'] as String?,
    );
  }

  /// Converts this ConnectionDetails to JSON.
  Map<String, dynamic> toJson() {
    return {
      if (clientId != null) 'clientId': clientId,
      if (connectionKey != null) 'connectionKey': connectionKey,
      if (connectionStateTtl != null) 'connectionStateTtl': connectionStateTtl,
      if (maxIdleInterval != null) 'maxIdleInterval': maxIdleInterval,
      if (maxMessageSize != null) 'maxMessageSize': maxMessageSize,
      if (maxFrameSize != null) 'maxFrameSize': maxFrameSize,
      if (maxInboundRate != null) 'maxInboundRate': maxInboundRate,
      if (serverId != null) 'serverId': serverId,
    };
  }
}
