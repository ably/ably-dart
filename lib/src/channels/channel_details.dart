/// Details of a channel, including its status and occupancy metrics.
///
/// Spec: CHD1
class ChannelDetails {
  ChannelDetails({
    required this.channelId,
    this.status,
  });

  /// Creates a ChannelDetails from a JSON map.
  factory ChannelDetails.fromMap(Map<String, dynamic> map) {
    return ChannelDetails(
      channelId: map['channelId'] as String? ?? map['name'] as String? ?? '',
      status: map['status'] != null
          ? ChannelStatus.fromMap(map['status'] as Map<String, dynamic>)
          : null,
    );
  }

  /// The channel identifier.
  ///
  /// Spec: CHD2a
  final String channelId;

  /// The current status of the channel.
  ///
  /// Spec: CHD2b
  final ChannelStatus? status;

  /// Converts this to a JSON map.
  Map<String, dynamic> toMap() {
    return {
      'channelId': channelId,
      if (status != null) 'status': status!.toMap(),
    };
  }
}

/// The status of a channel, including whether it's active and occupancy metrics.
///
/// Spec: CHS1
class ChannelStatus {
  ChannelStatus({
    required this.isActive,
    this.occupancy,
  });

  /// Creates a ChannelStatus from a JSON map.
  factory ChannelStatus.fromMap(Map<String, dynamic> map) {
    return ChannelStatus(
      isActive: map['isActive'] as bool? ?? false,
      occupancy: map['occupancy'] != null
          ? ChannelOccupancy.fromMap(map['occupancy'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Whether the channel is active.
  ///
  /// Spec: CHS2a
  final bool isActive;

  /// The occupancy metrics for this channel.
  ///
  /// Spec: CHS2b
  final ChannelOccupancy? occupancy;

  /// Converts this to a JSON map.
  Map<String, dynamic> toMap() {
    return {
      'isActive': isActive,
      if (occupancy != null) 'occupancy': occupancy!.toMap(),
    };
  }
}

/// Occupancy metrics for a channel.
///
/// Spec: CHO1
class ChannelOccupancy {
  ChannelOccupancy({
    this.metrics,
  });

  /// Creates a ChannelOccupancy from a JSON map.
  factory ChannelOccupancy.fromMap(Map<String, dynamic> map) {
    return ChannelOccupancy(
      metrics: map['metrics'] != null
          ? ChannelMetrics.fromMap(map['metrics'] as Map<String, dynamic>)
          : null,
    );
  }

  /// The metrics for this channel's occupancy.
  ///
  /// Spec: CHO2a
  final ChannelMetrics? metrics;

  /// Converts this to a JSON map.
  Map<String, dynamic> toMap() {
    return {
      if (metrics != null) 'metrics': metrics!.toMap(),
    };
  }
}

/// Metrics about channel occupancy.
///
/// Spec: CHM1
class ChannelMetrics {
  ChannelMetrics({
    this.connections,
    this.presenceConnections,
    this.presenceMembers,
    this.presenceSubscribers,
    this.publishers,
    this.subscribers,
    this.objectPublishers,
    this.objectSubscribers,
  });

  /// Creates ChannelMetrics from a JSON map.
  factory ChannelMetrics.fromMap(Map<String, dynamic> map) {
    return ChannelMetrics(
      connections: map['connections'] as int?,
      presenceConnections: map['presenceConnections'] as int?,
      presenceMembers: map['presenceMembers'] as int?,
      presenceSubscribers: map['presenceSubscribers'] as int?,
      publishers: map['publishers'] as int?,
      subscribers: map['subscribers'] as int?,
      objectPublishers: map['objectPublishers'] as int?,
      objectSubscribers: map['objectSubscribers'] as int?,
    );
  }

  /// The number of connections attached to this channel.
  ///
  /// Spec: CHM2a
  final int? connections;

  /// The number of connections with presence capability.
  ///
  /// Spec: CHM2b
  final int? presenceConnections;

  /// The number of presence members on this channel.
  ///
  /// Spec: CHM2c
  final int? presenceMembers;

  /// The number of connections subscribed to presence.
  ///
  /// Spec: CHM2d
  final int? presenceSubscribers;

  /// The number of connections publishing to this channel.
  ///
  /// Spec: CHM2e
  final int? publishers;

  /// The number of connections subscribed to this channel.
  ///
  /// Spec: CHM2f
  final int? subscribers;

  /// The number of connections publishing objects to this channel.
  ///
  /// Spec: CHM2g
  final int? objectPublishers;

  /// The number of connections subscribed to objects on this channel.
  ///
  /// Spec: CHM2h
  final int? objectSubscribers;

  /// Converts this to a JSON map.
  Map<String, dynamic> toMap() {
    return {
      if (connections != null) 'connections': connections,
      if (presenceConnections != null)
        'presenceConnections': presenceConnections,
      if (presenceMembers != null) 'presenceMembers': presenceMembers,
      if (presenceSubscribers != null)
        'presenceSubscribers': presenceSubscribers,
      if (publishers != null) 'publishers': publishers,
      if (subscribers != null) 'subscribers': subscribers,
      if (objectPublishers != null) 'objectPublishers': objectPublishers,
      if (objectSubscribers != null) 'objectSubscribers': objectSubscribers,
    };
  }
}
