import 'object_message.dart';

/// Base update event for LiveObjects.
///
/// Spec: RTLO4b4
class LiveObjectUpdate {
  LiveObjectUpdate({this.noop = false});

  /// Whether this update is a no-op (no actual change).
  ///
  /// Spec: RTLO4b4b
  final bool noop;
}

/// Base class for CRDT objects (LiveMap, LiveCounter).
///
/// Spec: RTLO1, RTLO2
abstract class LiveObject {
  /// Creates a LiveObject with the given objectId.
  ///
  /// Spec: RTLO3a1
  LiveObject({required this.objectId})
      : siteTimeserials = {},
        createOperationIsMerged = false,
        isTombstone = false,
        tombstonedAt = null;

  /// The object ID for this object.
  ///
  /// Spec: RTLO3a
  final String objectId;

  /// Map of serials keyed by siteCode, representing the last operations
  /// applied to this object.
  ///
  /// Spec: RTLO3b
  Map<String, String> siteTimeserials;

  /// Whether the corresponding CREATE operation has been applied.
  ///
  /// Spec: RTLO3c
  bool createOperationIsMerged;

  /// Whether this object has been tombstoned (marked for deletion).
  ///
  /// Spec: RTLO3d
  bool isTombstone;

  /// Timestamp when this object was tombstoned (milliseconds since epoch).
  ///
  /// Spec: RTLO3e
  int? tombstonedAt;

  /// Determines whether an operation should be applied based on serial.
  ///
  /// Spec: RTLO4a
  bool canApplyOperation(ObjectMessage message) {
    // RTLO4a3: Both serial and siteCode must be non-empty strings
    if (message.serial.isEmpty || message.siteCode.isEmpty) {
      return false;
    }

    // RTLO4a4: Get stored serial for this site
    final siteSerial = siteTimeserials[message.siteCode];

    // RTLO4a5: If no stored serial, accept
    if (siteSerial == null || siteSerial.isEmpty) {
      return true;
    }

    // RTLO4a6: Accept if message serial is lexicographically greater
    return message.serial.compareTo(siteSerial) > 0;
  }

  /// Tombstones this object (marks for deletion).
  ///
  /// Spec: RTLO4e
  void tombstone(ObjectMessage message) {
    // RTLO4e2: Set tombstone flag
    isTombstone = true;

    // RTLO4e3: Set tombstonedAt
    tombstonedAt =
        message.serialTimestamp ?? DateTime.now().millisecondsSinceEpoch;

    // RTLO4e4: Set data to zero value
    setZeroValue();
  }

  /// Set internal data to zero value. Subclasses must implement.
  ///
  /// Spec: RTLC4, RTLM4
  void setZeroValue();

  /// Apply an operation from an ObjectMessage.
  ///
  /// Returns a LiveObjectUpdate if applied, null if rejected.
  LiveObjectUpdate? applyOperation(ObjectMessage message);
}
