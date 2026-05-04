import 'package:meta/meta.dart';

import '../message/message.dart';

/// Specification for a batch publish operation.
///
/// Spec: BSP2
@immutable
class BatchPublishSpec {
  /// Creates a BatchPublishSpec.
  const BatchPublishSpec({
    required this.channels,
    required this.messages,
  });

  /// The channels to publish to.
  ///
  /// Spec: BSP2a
  final List<String> channels;

  /// The messages to publish.
  ///
  /// Spec: BSP2b
  final List<Message> messages;

  /// Converts this spec to a JSON map for transmission.
  Map<String, dynamic> toMap() {
    return {
      'channels': channels,
      'messages': messages.map((m) => m.toMap()).toList(),
    };
  }
}
