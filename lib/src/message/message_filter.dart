import 'package:meta/meta.dart';

/// Filter criteria for subscribing to messages.
///
/// When multiple criteria are specified, all must match for a message to be
/// delivered (AND semantics, per RTL22c).
///
/// Spec: MFI1, MFI2, MFI2a, MFI2b, MFI2c, MFI2d, MFI2e
@immutable
class MessageFilter {
  /// Creates a MessageFilter with the given criteria.
  const MessageFilter({
    this.isRef,
    this.refTimeserial,
    this.refType,
    this.name,
    this.clientId,
  });

  /// If true, match only messages that have `extras.ref`.
  /// If false, match only messages that do NOT have `extras.ref`.
  /// If null, no filtering on ref presence.
  ///
  /// Spec: MFI2a
  final bool? isRef;

  /// Match messages whose `extras.ref.timeserial` equals this value.
  ///
  /// Spec: MFI2b
  final String? refTimeserial;

  /// Match messages whose `extras.ref.type` equals this value.
  ///
  /// Spec: MFI2c
  final String? refType;

  /// Match messages whose `name` equals this value.
  ///
  /// Spec: MFI2d
  final String? name;

  /// Match messages whose `clientId` equals this value.
  ///
  /// Spec: MFI2e
  final String? clientId;

  @override
  String toString() {
    return 'MessageFilter('
        'isRef=$isRef, '
        'refTimeserial=$refTimeserial, '
        'refType=$refType, '
        'name=$name, '
        'clientId=$clientId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageFilter &&
        other.isRef == isRef &&
        other.refTimeserial == refTimeserial &&
        other.refType == refType &&
        other.name == name &&
        other.clientId == clientId;
  }

  @override
  int get hashCode =>
      Object.hash(isRef, refTimeserial, refType, name, clientId);
}
