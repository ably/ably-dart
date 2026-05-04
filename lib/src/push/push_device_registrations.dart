import '../pagination/paginated_result.dart';
import 'device_details.dart';

/// Admin interface for managing push device registrations.
///
/// Spec: RSH1b
abstract class PushDeviceRegistrations {
  /// Retrieves a device registration by deviceId.
  ///
  /// Returns a [DeviceDetails] if found, or throws a not-found error.
  ///
  /// Spec: RSH1b1
  Future<DeviceDetails> get(String deviceId);

  /// Lists device registrations filtered by the provided params.
  ///
  /// Supported params include `deviceId`, `clientId`, and `limit`.
  ///
  /// Spec: RSH1b2
  Future<PaginatedResult<DeviceDetails>> list(Map<String, String> params);

  /// Saves (creates or updates) a device registration.
  ///
  /// Issues a PUT request using the device's id.
  ///
  /// Spec: RSH1b3
  Future<DeviceDetails> save(DeviceDetails device);

  /// Removes a device registration by deviceId.
  ///
  /// Succeeds even if the device does not exist.
  ///
  /// Spec: RSH1b4
  Future<void> remove(String deviceId);

  /// Removes device registrations matching the provided params.
  ///
  /// Supported params include `clientId` and `deviceId`.
  /// Succeeds even if no devices match.
  ///
  /// Spec: RSH1b5
  Future<void> removeWhere(Map<String, String> params);
}
