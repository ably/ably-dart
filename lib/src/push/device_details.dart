import 'device_push_details.dart';

/// Details of a registered device.
///
/// Spec: PCD1–PCD7
class DeviceDetails {
  /// Creates a DeviceDetails instance.
  DeviceDetails({
    required this.id,
    this.clientId,
    this.formFactor,
    this.metadata,
    this.platform,
    this.push,
  });

  /// Creates a DeviceDetails from a JSON map.
  factory DeviceDetails.fromMap(Map<String, dynamic> map) {
    return DeviceDetails(
      id: map['id'] as String,
      clientId: map['clientId'] as String?,
      formFactor: map['formFactor'] as String?,
      metadata: map['metadata'] != null
          ? Map<String, String>.from(map['metadata'] as Map)
          : null,
      platform: map['platform'] as String?,
      push: map['push'] != null
          ? DevicePushDetails.fromMap(map['push'] as Map<String, dynamic>)
          : null,
    );
  }

  /// The id of the device registration.
  ///
  /// Spec: PCD2
  final String id;

  /// The clientId associated with this device registration.
  ///
  /// Spec: PCD3
  final String? clientId;

  /// The device form factor.
  ///
  /// One of: phone, tablet, desktop, tv, watch, car, embedded, other.
  ///
  /// Spec: PCD4
  final String? formFactor;

  /// A map of string key/value pairs containing registered metadata.
  ///
  /// Spec: PCD5
  final Map<String, String>? metadata;

  /// The device platform.
  ///
  /// One of: android, ios, browser.
  ///
  /// Spec: PCD6
  final String? platform;

  /// Details of the push registration for this device.
  ///
  /// Spec: PCD7
  final DevicePushDetails? push;

  /// Serializes to a JSON map.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
    };
    if (clientId != null) map['clientId'] = clientId;
    if (formFactor != null) map['formFactor'] = formFactor;
    if (metadata != null) map['metadata'] = metadata;
    if (platform != null) map['platform'] = platform;
    if (push != null) map['push'] = push!.toMap();
    return map;
  }
}
