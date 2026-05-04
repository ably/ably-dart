import 'package:meta/meta.dart';

/// Contains the result of an update or delete message operation.
///
/// Spec: UDR1, UDR2a
@immutable
class UpdateDeleteResult {
  /// Creates an UpdateDeleteResult.
  const UpdateDeleteResult({this.versionSerial});

  /// Creates an UpdateDeleteResult from a JSON map.
  factory UpdateDeleteResult.fromMap(Map<String, dynamic> map) {
    return UpdateDeleteResult(
      versionSerial: map['versionSerial'] as String?,
    );
  }

  /// The serial of the new version of the updated or deleted message.
  ///
  /// Will be null if the message was superseded by a subsequent update
  /// before it could be published.
  ///
  /// Spec: UDR2a
  final String? versionSerial;
}
