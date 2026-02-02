import 'dart:async';

/// Manages timers with owner-based lifecycle.
///
/// Timers are identified by (owner, name) pairs and automatically
/// cleaned up when cancelled. This prevents timer leaks in state machines.
class TimerManager {
  final Map<String, _TimerEntry> _timers = {};

  /// Schedules a one-shot timer associated with an owner.
  ///
  /// If a timer with the same (owner, name) already exists, it is cancelled first.
  void schedule({
    required Object owner,
    required String name,
    required Duration duration,
    required void Function() callback,
  }) {
    final key = _makeKey(owner, name);

    // Cancel existing timer with same key
    _cancelKey(key);

    final timer = Timer(duration, () {
      _timers.remove(key);
      callback();
    });

    _timers[key] = _TimerEntry(
      owner: owner,
      name: name,
      timer: timer,
    );
  }

  /// Schedules a periodic timer associated with an owner.
  ///
  /// If a timer with the same (owner, name) already exists, it is cancelled first.
  void schedulePeriodic({
    required Object owner,
    required String name,
    required Duration period,
    required void Function(Timer) callback,
  }) {
    final key = _makeKey(owner, name);

    _cancelKey(key);

    final timer = Timer.periodic(period, callback);

    _timers[key] = _TimerEntry(
      owner: owner,
      name: name,
      timer: timer,
    );
  }

  /// Cancels a specific timer.
  void cancel({required Object owner, required String name}) {
    final key = _makeKey(owner, name);
    _cancelKey(key);
  }

  /// Cancels all timers for an owner.
  void cancelAll({required Object owner}) {
    final keysToRemove = <String>[];
    for (final entry in _timers.entries) {
      if (entry.value.owner == owner) {
        entry.value.timer.cancel();
        keysToRemove.add(entry.key);
      }
    }
    for (final key in keysToRemove) {
      _timers.remove(key);
    }
  }

  /// Checks if a timer is active.
  bool isActive({required Object owner, required String name}) {
    final key = _makeKey(owner, name);
    return _timers.containsKey(key);
  }

  String _makeKey(Object owner, String name) {
    return '${owner.hashCode}_$name';
  }

  void _cancelKey(String key) {
    _timers[key]?.timer.cancel();
    _timers.remove(key);
  }

  /// Disposes all timers.
  void dispose() {
    for (final entry in _timers.values) {
      entry.timer.cancel();
    }
    _timers.clear();
  }
}

class _TimerEntry {
  _TimerEntry({
    required this.owner,
    required this.name,
    required this.timer,
  });

  final Object owner;
  final String name;
  final Timer timer;
}
