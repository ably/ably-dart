import 'dart:async';

import '../error/error_info.dart';
import 'channel_event.dart';
import 'channel_mode.dart';
import 'channel_state.dart';
import 'channel_state_change.dart';
import 'realtime_channel_options.dart';

/// A realtime channel for pub/sub messaging.
///
/// Spec: RTL
class RealtimeChannel {
  /// Creates a RealtimeChannel instance.
  RealtimeChannel({
    required Object realtime,
    required String name,
    RealtimeChannelOptions? options,
  })  : _realtime = realtime,
        _name = name,
        _options = options ?? const RealtimeChannelOptions(),
        _state = ChannelState.initialized;

  // Kept for future use when implementing full channel logic
  // ignore: unused_field
  final Object _realtime;
  final String _name;
  RealtimeChannelOptions _options;

  ChannelState _state;
  ErrorInfo? _errorReason;

  final _stateChangeController =
      StreamController<ChannelStateChange>.broadcast();

  /// The name of this channel.
  ///
  /// Spec: RTL23
  String get name => _name;

  /// The current channel options.
  RealtimeChannelOptions get options => _options;

  /// The current channel state.
  ///
  /// Spec: RTL2
  ChannelState get state => _state;

  /// The channel modes as returned by the server on attach.
  ///
  /// This is populated after a successful attach and reflects
  /// the actual modes granted by the server.
  ///
  /// Spec: RTL4m
  List<ChannelMode>? get modes => _modes;
  List<ChannelMode>? _modes;

  /// Error information for the current state (if failed/suspended).
  ///
  /// Spec: RTL24
  ErrorInfo? get errorReason => _errorReason;

  /// Listens to channel state changes.
  ///
  /// If [event] is provided, only emits changes matching that event.
  /// If [event] is null, emits all state changes.
  ///
  /// Spec: RTL2
  Stream<ChannelStateChange> on([ChannelEvent? event]) {
    if (event == null) {
      return _stateChangeController.stream;
    }

    return _stateChangeController.stream
        .where((change) => change.event == event);
  }

  /// Attaches to this channel.
  ///
  /// If already attached, this is a no-op.
  ///
  /// Spec: RTL4
  Future<void> attach() async {
    switch (_state) {
      case ChannelState.attached:
        // Already attached - no-op (RTL4a)
        return;

      case ChannelState.attaching:
        // Already attaching - wait for completion
        await _waitForState(ChannelState.attached);
        return;

      case ChannelState.failed:
        // Clear error and proceed (RTL4g)
        _errorReason = null;
        break;

      case ChannelState.detaching:
        // Wait for detach to complete, then attach
        await _waitForState(ChannelState.detached);
        break;

      default:
        break;
    }

    // Transition to attaching
    _transitionTo(ChannelState.attaching);

    // In a full implementation, this would:
    // 1. Check connection state
    // 2. Send ATTACH protocol message
    // 3. Wait for ATTACHED response
    // For now, simulate successful attach
    await _simulateAttach();
  }

  /// Detaches from this channel.
  ///
  /// If already detached, this is a no-op.
  ///
  /// Spec: RTL5
  Future<void> detach() async {
    switch (_state) {
      case ChannelState.initialized:
      case ChannelState.detached:
        // Already detached - no-op (RTL5a)
        return;

      case ChannelState.detaching:
        // Already detaching - wait for completion
        await _waitForState(ChannelState.detached);
        return;

      case ChannelState.failed:
        // Transition directly to detached (RTL5g)
        _transitionTo(ChannelState.detached);
        return;

      case ChannelState.attaching:
        // Wait for attach to complete, then detach
        await _waitForState(ChannelState.attached);
        break;

      default:
        break;
    }

    // Transition to detaching
    _transitionTo(ChannelState.detaching);

    // In a full implementation, this would:
    // 1. Send DETACH protocol message
    // 2. Wait for DETACHED response
    // For now, simulate successful detach
    await _simulateDetach();
  }

  /// Simulates an attach operation for basic implementation.
  Future<void> _simulateAttach() async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 10));

    // Check if still attaching (might have been cancelled)
    if (_state != ChannelState.attaching) {
      return;
    }

    // Simulate successful attach
    _transitionTo(ChannelState.attached);
  }

  /// Simulates a detach operation for basic implementation.
  Future<void> _simulateDetach() async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 10));

    // Check if still detaching (might have been cancelled)
    if (_state != ChannelState.detaching) {
      return;
    }

    // Simulate successful detach
    _transitionTo(ChannelState.detached);
  }

  /// Waits for the channel to reach a specific state.
  Future<void> _waitForState(ChannelState targetState) async {
    if (_state == targetState) {
      return;
    }

    await _stateChangeController.stream
        .firstWhere((change) => change.current == targetState);
  }

  /// Transitions to a new state and emits a state change event.
  void _transitionTo(
    ChannelState newState, {
    ErrorInfo? error,
    bool resumed = false,
    bool? hasBacklog,
  }) {
    if (_state == newState) {
      return;
    }

    final previous = _state;
    _state = newState;

    // Update error reason if provided
    if (error != null) {
      _errorReason = error;
    } else if (newState == ChannelState.attached ||
        newState == ChannelState.detached) {
      // Clear error when successfully attached or detached
      _errorReason = null;
    }

    // Map state to event (state changes emit events of the same name)
    final event = ChannelEvent.values.firstWhere(
      (e) => e.name == newState.name,
      orElse: () => ChannelEvent.update,
    );

    final change = ChannelStateChange(
      event: event,
      current: newState,
      previous: previous,
      reason: error,
      resumed: resumed,
      hasBacklog: hasBacklog,
    );

    _stateChangeController.add(change);
  }

  /// Sets or updates the channel options.
  ///
  /// If the channel is in the attached or attaching state and the new options
  /// include params or modes, this will trigger a reattachment to apply the
  /// new options on the server.
  ///
  /// Spec: RTL16, RTL16a
  Future<void> setOptions(RealtimeChannelOptions options) async {
    final needsReattach = options.requiresReattachment &&
        (_state == ChannelState.attached || _state == ChannelState.attaching);

    _options = options;

    if (needsReattach) {
      // In a full implementation, this would send an ATTACH message
      // with the new params/modes and wait for ATTACHED response.
      // For now, simulate the reattachment.
      if (_state == ChannelState.attached) {
        _transitionTo(ChannelState.attaching);
        await _simulateAttach();
      }
      // If attaching, the current attach operation will use the new options
    }
  }

  /// Updates the channel options without triggering reattachment.
  ///
  /// This is used internally by RealtimeChannels.get() for the soft-deprecated
  /// RTS3c behavior where options are updated but reattachment is not allowed.
  void updateOptionsWithoutReattach(RealtimeChannelOptions options) {
    _options = options;
  }

  /// Disposes resources used by this channel.
  void dispose() {
    _stateChangeController.close();
  }
}
