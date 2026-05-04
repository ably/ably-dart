import 'device_details.dart';

/// Represents the current device as a target for push notifications.
///
/// Extends [DeviceDetails] with a [deviceIdentityToken] and [deviceSecret]
/// that are used for push device authentication (RSH6).
///
/// Spec: RSH8
class LocalDevice extends DeviceDetails {
  LocalDevice({
    required super.id,
    super.clientId,
    super.formFactor,
    super.metadata,
    super.platform,
    super.push,
    this.deviceIdentityToken,
    this.deviceSecret,
  });

  /// Creates a LocalDevice from a JSON map.
  factory LocalDevice.fromMap(Map<String, dynamic> map) {
    return LocalDevice(
      id: map['id'] as String,
      clientId: map['clientId'] as String?,
      formFactor: map['formFactor'] as String?,
      metadata: map['metadata'] != null
          ? Map<String, String>.from(map['metadata'] as Map)
          : null,
      platform: map['platform'] as String?,
      deviceIdentityToken: map['deviceIdentityToken'] as String?,
      deviceSecret: map['deviceSecret'] as String?,
    );
  }

  /// The device identity token, populated after registration.
  ///
  /// Spec: RSH8k1
  final String? deviceIdentityToken;

  /// The device secret, generated on first activation.
  ///
  /// Spec: RSH8k2
  final String? deviceSecret;

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    if (deviceIdentityToken != null) {
      map['deviceIdentityToken'] = deviceIdentityToken;
    }
    if (deviceSecret != null) {
      map['deviceSecret'] = deviceSecret;
    }
    return map;
  }
}
