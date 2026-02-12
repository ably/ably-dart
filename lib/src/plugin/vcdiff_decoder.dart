import 'dart:typed_data';

/// Interface for decoding vcdiff-encoded message payloads.
///
/// Implementations wrap a platform-specific vcdiff library and are passed
/// to the SDK via `ClientOptions.plugins` with the key `'vcdiff'`.
///
/// Spec: VD1, VD2, VD2a
abstract class VCDiffDecoder {
  /// Decodes a vcdiff [delta] against a [base] payload, returning the
  /// reconstructed message payload.
  ///
  /// Both arguments and the return value are raw bytes.
  ///
  /// Spec: VD2a, PC3a
  Uint8List decode(Uint8List delta, Uint8List base);
}
