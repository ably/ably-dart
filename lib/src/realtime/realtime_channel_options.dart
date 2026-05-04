import 'package:meta/meta.dart';

import '../crypto/cipher_params.dart';
import 'channel_mode.dart';

/// Options for a realtime channel.
///
/// Spec: TB1, TB2
@immutable
class RealtimeChannelOptions {
  /// Creates RealtimeChannelOptions.
  ///
  /// Spec: TB1
  const RealtimeChannelOptions({
    this.cipherParams,
    this.params,
    this.modes,
    this.attachOnSubscribe = true,
  });

  /// Encryption parameters for this channel.
  ///
  /// When set, messages are encrypted/decrypted using these parameters.
  ///
  /// Spec: TB2b
  final CipherParams? cipherParams;

  /// Channel parameters as key/value pairs.
  ///
  /// These are sent to the server when attaching to the channel.
  /// Examples include `rewind`, `delta`, etc.
  ///
  /// Spec: TB2c
  final Map<String, String>? params;

  /// Channel modes defining the capabilities requested.
  ///
  /// Spec: TB2d
  final List<ChannelMode>? modes;

  /// Whether calling subscribe should trigger an implicit attach.
  ///
  /// Defaults to true.
  ///
  /// Spec: TB4
  final bool attachOnSubscribe;

  /// Creates channel options with the given cipher key.
  ///
  /// The [key] can be a base64 string or raw bytes.
  ///
  /// Spec: TB3
  static RealtimeChannelOptions withCipherKey(dynamic key) {
    return RealtimeChannelOptions(
      cipherParams: CipherParams.fromKey(key),
    );
  }

  /// Returns true if this options would require a reattachment when applied
  /// to an already-attached channel.
  ///
  /// Reattachment is required when params or modes are specified.
  ///
  /// Spec: RTL16a
  bool get requiresReattachment => params != null || modes != null;

  /// Creates a copy of this options with the given fields replaced.
  RealtimeChannelOptions copyWith({
    CipherParams? cipherParams,
    Map<String, String>? params,
    List<ChannelMode>? modes,
    bool? attachOnSubscribe,
  }) {
    return RealtimeChannelOptions(
      cipherParams: cipherParams ?? this.cipherParams,
      params: params ?? this.params,
      modes: modes ?? this.modes,
      attachOnSubscribe: attachOnSubscribe ?? this.attachOnSubscribe,
    );
  }

  @override
  String toString() {
    return 'RealtimeChannelOptions('
        'cipherParams: $cipherParams, '
        'params: $params, '
        'modes: $modes, '
        'attachOnSubscribe: $attachOnSubscribe)';
  }
}
