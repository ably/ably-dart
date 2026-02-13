import 'dart:typed_data';

/// PathObject for a string primitive value at a path.
///
/// Obtained via `PathObject.asString()`.
///
/// Spec: PO5a
abstract class StringPathObject {
  /// The fully-qualified path string.
  String path();

  /// Returns the string value at this path, or null if unresolvable
  /// or not a string.
  String? value();

  /// Returns the string value (alias for [value]).
  ///
  /// Spec: PO5e
  String? compact();

  /// Returns the string value (same as [compact] for strings).
  ///
  /// Spec: PO5f
  String? compactJson();
}

/// PathObject for a numeric primitive value at a path.
///
/// Obtained via `PathObject.asNumber()`.
///
/// Spec: PO5b
abstract class NumberPathObject {
  /// The fully-qualified path string.
  String path();

  /// Returns the numeric value at this path, or null if unresolvable
  /// or not a number.
  num? value();

  /// Returns the numeric value (alias for [value]).
  ///
  /// Spec: PO5e
  num? compact();

  /// Returns the numeric value (same as [compact] for numbers).
  ///
  /// Spec: PO5f
  num? compactJson();
}

/// PathObject for a boolean primitive value at a path.
///
/// Obtained via `PathObject.asBoolean()`.
///
/// Spec: PO5c
abstract class BooleanPathObject {
  /// The fully-qualified path string.
  String path();

  /// Returns the boolean value at this path, or null if unresolvable
  /// or not a boolean.
  bool? value();

  /// Returns the boolean value (alias for [value]).
  ///
  /// Spec: PO5e
  bool? compact();

  /// Returns the boolean value (same as [compact] for booleans).
  ///
  /// Spec: PO5f
  bool? compactJson();
}

/// PathObject for a binary primitive value at a path.
///
/// Obtained via `PathObject.asBinary()`.
///
/// Spec: PO5d
abstract class BinaryPathObject {
  /// The fully-qualified path string.
  String path();

  /// Returns the binary data at this path, or null if unresolvable
  /// or not binary.
  ///
  /// Spec: PO5d1
  Uint8List? value();

  /// Returns the binary data (alias for [value]).
  ///
  /// Spec: PO5e
  Uint8List? compact();

  /// Returns the binary data as a base64-encoded string, or null.
  ///
  /// Spec: PO5d2, PO5f
  String? compactJson();
}
