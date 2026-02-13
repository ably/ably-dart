import '../message/annotation.dart';
import '../pagination/paginated_result.dart';

/// A REST interface for managing annotations on messages.
///
/// Spec: RSAN1–RSAN3
abstract class RestAnnotations {
  /// Publishes an annotation on a message.
  ///
  /// [messageSerial] is the serial of the message to annotate.
  /// [annotation] is the annotation to publish. Must have a non-null [Annotation.type].
  ///
  /// Spec: RSAN1
  Future<void> publish(String messageSerial, Annotation annotation);

  /// Deletes an annotation from a message.
  ///
  /// [messageSerial] is the serial of the message.
  /// [annotation] describes which annotation to delete.
  ///
  /// Spec: RSAN2
  Future<void> delete(String messageSerial, Annotation annotation);

  /// Retrieves annotations for a message.
  ///
  /// [messageSerial] is the serial of the message.
  /// Optional [params] are sent as querystring parameters.
  ///
  /// Spec: RSAN3
  Future<PaginatedResult<Annotation>> get(
    String messageSerial, {
    Map<String, String>? params,
  });
}
