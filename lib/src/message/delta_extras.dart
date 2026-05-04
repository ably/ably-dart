import 'package:meta/meta.dart';

/// Delta compression metadata.
@immutable
class DeltaExtras {
  /// Creates a DeltaExtras instance.
  const DeltaExtras({
    this.from,
    this.format,
  });

  /// Creates a DeltaExtras from a JSON map.
  factory DeltaExtras.fromMap(Map<String, dynamic> map) {
    return DeltaExtras(
      from: map['from'] as String?,
      format: map['format'] as String?,
    );
  }

  /// The message ID that the delta was generated from.
  final String? from;

  /// The delta compression format (e.g., 'vcdiff').
  final String? format;

  /// Converts this DeltaExtras to a JSON map.
  Map<String, dynamic> toMap() {
    return {
      if (from != null) 'from': from,
      if (format != null) 'format': format,
    };
  }

  @override
  String toString() {
    return 'DeltaExtras(from=$from, format=$format)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeltaExtras && other.from == from && other.format == format;
  }

  @override
  int get hashCode => Object.hash(from, format);
}
