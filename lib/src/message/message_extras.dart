import 'package:meta/meta.dart';

import 'delta_extras.dart';

/// Message extras containing metadata and ancillary payloads.
///
/// Spec: TM2h
@immutable
class MessageExtras {
  /// Creates a MessageExtras instance.
  const MessageExtras({
    Map<String, dynamic>? data,
    this.delta,
  }) : _data = data;

  /// Creates a MessageExtras from a JSON map.
  factory MessageExtras.fromMap(Map<String, dynamic> map) {
    return MessageExtras(
      data: Map<String, dynamic>.from(map),
      delta: map['delta'] != null
          ? DeltaExtras.fromMap(map['delta'] as Map<String, dynamic>)
          : null,
    );
  }

  final Map<String, dynamic>? _data;

  /// The raw extras data.
  Map<String, dynamic> get data => _data ?? {};

  /// Delta compression metadata.
  final DeltaExtras? delta;

  /// Converts this MessageExtras to a JSON map.
  Map<String, dynamic> toMap() {
    return _data ?? {};
  }

  @override
  String toString() {
    return 'MessageExtras(delta=$delta, data=$_data)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageExtras && other.delta == delta;
  }

  @override
  int get hashCode => delta.hashCode;
}
