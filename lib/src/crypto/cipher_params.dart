import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Parameters for message encryption.
///
/// Spec: RSE1
@immutable
class CipherParams {
  /// Creates CipherParams.
  const CipherParams({
    required this.key,
    this.algorithm = 'aes',
    this.mode = 'cbc',
    this.keyLength,
  });

  /// Creates CipherParams from a key.
  ///
  /// The [key] can be a base64 string or a [Uint8List].
  factory CipherParams.fromKey(dynamic key) {
    final Uint8List keyBytes;
    if (key is String) {
      keyBytes = base64.decode(key);
    } else if (key is Uint8List) {
      keyBytes = key;
    } else {
      throw ArgumentError('Key must be a String or Uint8List');
    }

    final keyLength = keyBytes.length * 8;
    if (keyLength != 128 && keyLength != 256) {
      throw ArgumentError('Key must be 128 or 256 bits, got $keyLength bits');
    }

    return CipherParams(
      key: keyBytes,
      keyLength: keyLength,
    );
  }

  /// The encryption key.
  final Uint8List key;

  /// The encryption algorithm (default: 'aes').
  final String algorithm;

  /// The cipher mode (default: 'cbc').
  final String mode;

  /// The key length in bits.
  final int? keyLength;

  @override
  String toString() {
    return 'CipherParams(algorithm=$algorithm, mode=$mode, '
        'keyLength=$keyLength)';
  }
}
