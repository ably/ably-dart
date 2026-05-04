import 'dart:math';

/// Generates a unique channel name for testing.
///
/// The format is: test-<prefix>-<random>
/// where <random> is a 6-character alphanumeric string.
///
/// This ensures channel names don't collide between concurrent tests
/// or leak state from previous test runs.
String testChannelName(String prefix) {
  final random = _generateRandomString(6);
  return 'test-$prefix-$random';
}

/// Generates a random alphanumeric string of the given length.
String _generateRandomString(int length) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random();
  return String.fromCharCodes(
    Iterable.generate(
      length,
      (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    ),
  );
}
