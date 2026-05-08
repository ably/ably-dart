import 'package:test/test.dart';

const List<String> protocols = ['json', 'msgpack'];

/// Wraps a [group] to run once per protocol variant (G1 compliance).
///
/// Produces test output like:
///   suite name [json]
///     ... tests run normally ...
///   suite name [msgpack]
///     ... tests run normally ...
void groupEachProtocol(
  String name,
  void Function(String protocol) body, {
  Object? skip,
}) {
  for (final protocol in protocols) {
    group('$name [$protocol]', () {
      body(protocol);
    }, skip: skip);
  }
}
