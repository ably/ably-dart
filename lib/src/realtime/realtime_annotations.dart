import 'dart:async';

import '../message/annotation.dart';
import '../pagination/paginated_result.dart';

/// Provides realtime annotation operations for a channel.
///
/// Spec: RTAN
abstract class RealtimeAnnotations {
  /// Publishes an annotation on a message via the realtime connection.
  ///
  /// Spec: RTAN1
  Future<void> publish(String messageSerial, Annotation annotation);

  /// Deletes an annotation from a message via the realtime connection.
  ///
  /// Spec: RTAN2
  Future<void> delete(String messageSerial, Annotation annotation);

  /// Retrieves annotations for a message via the REST API.
  ///
  /// Spec: RTAN3
  Future<PaginatedResult<Annotation>> get(
    String messageSerial, {
    Map<String, String>? params,
  });

  /// Subscribes to annotations on this channel.
  ///
  /// If [type] is provided, only annotations matching that type are delivered.
  ///
  /// Spec: RTAN4
  void subscribe(void Function(Annotation) listener, {String? type});

  /// Unsubscribes from annotations on this channel.
  ///
  /// Spec: RTAN5
  void unsubscribe({void Function(Annotation)? listener, String? type});
}
