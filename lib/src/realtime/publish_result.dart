import 'package:meta/meta.dart';

/// Contains the result of a publish operation.
///
/// Spec: PBR1
@immutable
class PublishResult {
  /// Creates a PublishResult.
  const PublishResult({required this.serials});

  /// An array of message serials corresponding 1:1 to the messages that were
  /// published. A serial may be null if the message was discarded due to a
  /// configured conflation rule.
  ///
  /// Spec: PBR2a
  final List<String?> serials;

  /// Creates a PublishResult from a JSON map.
  factory PublishResult.fromMap(Map<String, dynamic> map) {
    return PublishResult(
      serials: (map['serials'] as List?)?.cast<String?>() ?? [],
    );
  }
}
