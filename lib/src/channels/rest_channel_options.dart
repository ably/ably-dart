import 'package:meta/meta.dart';

import '../crypto/cipher_params.dart';

/// Options for a REST channel.
@immutable
class RestChannelOptions {
  /// Creates RestChannelOptions.
  const RestChannelOptions({
    this.cipherParams,
  });

  /// Encryption parameters for this channel.
  ///
  /// When set, messages are encrypted/decrypted using these parameters.
  final CipherParams? cipherParams;

  /// Creates channel options with the given cipher key.
  ///
  /// The [key] can be a base64 string or raw bytes.
  static RestChannelOptions withCipherKey(dynamic key) {
    return RestChannelOptions(
      cipherParams: CipherParams.fromKey(key),
    );
  }
}
