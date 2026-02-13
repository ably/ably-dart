import '../error/error_info.dart';

/// Details of the push registration for a given device.
///
/// Spec: PCP1–PCP4
class DevicePushDetails {
  /// Creates a DevicePushDetails instance.
  DevicePushDetails({
    this.errorReason,
    this.recipient = const {},
    this.state,
  });

  /// Creates a DevicePushDetails from a JSON map.
  factory DevicePushDetails.fromMap(Map<String, dynamic> map) {
    return DevicePushDetails(
      errorReason: map['errorReason'] != null
          ? ErrorInfo.fromMap(map['errorReason'] as Map<String, dynamic>)
          : null,
      recipient: map['recipient'] != null
          ? Map<String, dynamic>.from(map['recipient'] as Map)
          : const {},
      state: map['state'] as String?,
    );
  }

  /// Any error information associated with the registration.
  ///
  /// Spec: PCP2
  final ErrorInfo? errorReason;

  /// Details of the push transport and address.
  ///
  /// Spec: PCP3
  final Map<String, dynamic> recipient;

  /// The state of the push registration: Active, Failing, or Failed.
  ///
  /// Spec: PCP4
  final String? state;

  /// Serializes to a JSON map.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'recipient': recipient,
    };
    if (errorReason != null) {
      map['errorReason'] = {
        if (errorReason!.code != null) 'code': errorReason!.code,
        if (errorReason!.statusCode != null)
          'statusCode': errorReason!.statusCode,
        if (errorReason!.message != null) 'message': errorReason!.message,
      };
    }
    if (state != null) map['state'] = state;
    return map;
  }
}
