import 'dart:math';
import 'dart:typed_data';

import 'cipher_params.dart';

/// Crypto utilities for message encryption.
///
/// Spec: RSE
class Crypto {
  Crypto._();

  /// Default encryption algorithm.
  static const String defaultAlgorithm = 'aes';

  /// Default cipher mode.
  static const String defaultMode = 'cbc';

  /// Default key length in bits.
  static const int defaultKeyLengthInBits = 256;

  /// 256-bit key length constant.
  static const int keyLength256bits = 256;

  /// 128-bit key length constant.
  static const int keyLength128bits = 128;

  /// Gets the default cipher parameters for a key.
  ///
  /// Spec: RSE1
  static CipherParams getDefaultParams({required dynamic key}) {
    return CipherParams.fromKey(key);
  }

  /// Generates a random encryption key.
  ///
  /// Spec: RSE2
  static Uint8List generateRandomKey({
    int keyLength = defaultKeyLengthInBits,
  }) {
    if (keyLength != 128 && keyLength != 256) {
      throw ArgumentError('Key length must be 128 or 256 bits');
    }

    final random = Random.secure();
    final keyBytes = keyLength ~/ 8;
    return Uint8List.fromList(
      List.generate(keyBytes, (_) => random.nextInt(256)),
    );
  }

  /// Validates that the key length is supported.
  static void ensureSupportedKeyLength(Uint8List key) {
    final keyLengthBits = key.length * 8;
    if (keyLengthBits != 128 && keyLengthBits != 256) {
      throw ArgumentError(
        'Key length must be 128 or 256 bits, got $keyLengthBits bits',
      );
    }
  }
}
