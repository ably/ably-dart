import 'package:meta/meta.dart';

/// Options for creating a derived channel.
///
/// Spec: DO1, DO2
@immutable
class DeriveOptions {
  /// Creates DeriveOptions with a filter expression.
  ///
  /// The [filter] must be a valid JMESPath string expression.
  ///
  /// Spec: DO2a
  const DeriveOptions({
    required this.filter,
  });

  /// The JMESPath filter expression.
  ///
  /// This expression is used to filter messages on the derived channel.
  ///
  /// Spec: DO2a
  final String filter;

  @override
  String toString() => 'DeriveOptions(filter: $filter)';
}
