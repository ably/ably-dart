import 'dart:async';

/// Polls [check] repeatedly until it returns a non-null value, then returns
/// that value.
///
/// Throws a [TimeoutException] if [timeout] elapses without a non-null result.
Future<T> pollUntil<T>(
  Future<T?> Function() check, {
  Duration interval = const Duration(milliseconds: 500),
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final result = await check();
    if (result != null) return result;
    await Future<void>.delayed(interval);
  }
  throw TimeoutException('pollUntil timed out after $timeout');
}
