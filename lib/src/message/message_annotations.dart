import 'package:meta/meta.dart';

/// Contains information about annotations associated with a message.
///
/// Spec: TM2u, TM8, TM8a
@immutable
class MessageAnnotations {
  /// Creates a MessageAnnotations.
  const MessageAnnotations({this.summary = const {}});

  /// Creates a MessageAnnotations from a JSON map.
  factory MessageAnnotations.fromMap(Map<String, dynamic> map) {
    final rawSummary = map['summary'] as Map<String, dynamic>?;
    return MessageAnnotations(
      summary:
          rawSummary != null ? Map<String, Object>.from(rawSummary) : const {},
    );
  }

  /// A summary of all annotations made to the message.
  ///
  /// A missing summary field indicates an empty summary.
  ///
  /// Spec: TM8a
  final Map<String, Object> summary;
}
