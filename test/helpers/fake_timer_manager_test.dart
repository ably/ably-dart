import 'package:clock/clock.dart';
import 'package:test/test.dart';

import 'fake_timer_manager.dart';

void main() {
  group('TestClock', () {
    test('advances time', () {
      final testClock = TestClock(DateTime(2024, 1, 1, 12, 0));

      withClock(testClock, () {
        expect(clock.now(), DateTime(2024, 1, 1, 12, 0));

        testClock.advance(const Duration(hours: 1));
        expect(clock.now(), DateTime(2024, 1, 1, 13, 0));
      });
    });

    test('setTime sets absolute time', () {
      final testClock = TestClock(DateTime(2024, 1, 1, 12, 0));

      withClock(testClock, () {
        testClock.setTime(DateTime(2025, 6, 15, 10, 30));
        expect(clock.now(), DateTime(2025, 6, 15, 10, 30));
      });
    });
  });

  group('FakeTimerManager', () {
    test('fires one-shot timer when time elapses', () {
      final testClock = TestClock(DateTime(2024, 1, 1, 12, 0));
      final fakeTimers = FakeTimerManager(testClock);

      var fired = false;
      final owner = Object();

      withClock(testClock, () {
        fakeTimers.schedule(
          owner: owner,
          name: 'test',
          duration: const Duration(seconds: 5),
          callback: () => fired = true,
        );

        expect(fired, isFalse);

        // Advance less than 5 seconds - should not fire
        fakeTimers.elapseTime(const Duration(seconds: 3));
        expect(fired, isFalse);

        // Advance past 5 seconds - should fire
        fakeTimers.elapseTime(const Duration(seconds: 3));
        expect(fired, isTrue);
      });
    });

    test('fires multiple timers in order', () {
      final testClock = TestClock(DateTime(2024, 1, 1, 12, 0));
      final fakeTimers = FakeTimerManager(testClock);

      final firedOrder = <String>[];
      final owner = Object();

      withClock(testClock, () {
        fakeTimers.schedule(
          owner: owner,
          name: 'second',
          duration: const Duration(seconds: 10),
          callback: () => firedOrder.add('second'),
        );
        fakeTimers.schedule(
          owner: owner,
          name: 'first',
          duration: const Duration(seconds: 5),
          callback: () => firedOrder.add('first'),
        );

        fakeTimers.elapseTime(const Duration(seconds: 15));

        expect(firedOrder, ['first', 'second']);
      });
    });

    test('cancel removes timer', () {
      final testClock = TestClock(DateTime(2024, 1, 1, 12, 0));
      final fakeTimers = FakeTimerManager(testClock);

      var fired = false;
      final owner = Object();

      withClock(testClock, () {
        fakeTimers.schedule(
          owner: owner,
          name: 'test',
          duration: const Duration(seconds: 5),
          callback: () => fired = true,
        );

        fakeTimers.cancel(owner: owner, name: 'test');
        fakeTimers.elapseTime(const Duration(seconds: 10));

        expect(fired, isFalse);
      });
    });

    test('cancelAll removes all timers for owner', () {
      final testClock = TestClock(DateTime(2024, 1, 1, 12, 0));
      final fakeTimers = FakeTimerManager(testClock);

      var fired1 = false;
      var fired2 = false;
      final owner = Object();

      withClock(testClock, () {
        fakeTimers.schedule(
          owner: owner,
          name: 'test1',
          duration: const Duration(seconds: 5),
          callback: () => fired1 = true,
        );
        fakeTimers.schedule(
          owner: owner,
          name: 'test2',
          duration: const Duration(seconds: 5),
          callback: () => fired2 = true,
        );

        fakeTimers.cancelAll(owner: owner);
        fakeTimers.elapseTime(const Duration(seconds: 10));

        expect(fired1, isFalse);
        expect(fired2, isFalse);
      });
    });

    test('isActive returns correct state', () {
      final testClock = TestClock(DateTime(2024, 1, 1, 12, 0));
      final fakeTimers = FakeTimerManager(testClock);

      final owner = Object();

      withClock(testClock, () {
        expect(fakeTimers.isActive(owner: owner, name: 'test'), isFalse);

        fakeTimers.schedule(
          owner: owner,
          name: 'test',
          duration: const Duration(seconds: 5),
          callback: () {},
        );

        expect(fakeTimers.isActive(owner: owner, name: 'test'), isTrue);

        fakeTimers.elapseTime(const Duration(seconds: 10));

        expect(fakeTimers.isActive(owner: owner, name: 'test'), isFalse);
      });
    });
  });

  group('Clock affects code using clock.now()', () {
    test('token expiry check respects fake clock', () {
      final testClock = TestClock(DateTime(2024, 1, 1, 12, 0));

      withClock(testClock, () {
        // Expires 1 hour from "now"
        final expiresAt = clock.now().millisecondsSinceEpoch + 3600000;

        // Not expired yet
        expect(clock.now().millisecondsSinceEpoch >= expiresAt, isFalse);

        // Advance 2 hours
        testClock.advance(const Duration(hours: 2));

        // Now expired
        expect(clock.now().millisecondsSinceEpoch >= expiresAt, isTrue);
      });
    });
  });
}
