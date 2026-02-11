import '../message/presence_message.dart';
import '../presence/presence_action.dart';

/// Determines whether [incoming] is newer than [existing] per RTP2b.
///
/// RTP2b1: If either message is "synthesized" (connectionId is not a prefix
/// of its id), compare by timestamp. RTP2b1a: equal timestamps means incoming
/// is considered newer.
///
/// RTP2b2: Otherwise, parse id as `connectionId:msgSerial:index` and compare
/// msgSerial then index numerically.
bool _isNewer(PresenceMessage incoming, PresenceMessage existing) {
  final incomingSynthesized = _isSynthesized(incoming);
  final existingSynthesized = _isSynthesized(existing);

  if (incomingSynthesized || existingSynthesized) {
    // RTP2b1: compare by timestamp
    final incomingTs = incoming.timestamp?.millisecondsSinceEpoch ?? 0;
    final existingTs = existing.timestamp?.millisecondsSinceEpoch ?? 0;
    // RTP2b1a: equal timestamps means incoming is newer
    return incomingTs >= existingTs;
  }

  // RTP2b2: compare by msgSerial:index parsed from id
  final incomingParts = _parseId(incoming.id!, incoming.connectionId!);
  final existingParts = _parseId(existing.id!, existing.connectionId!);

  if (incomingParts.msgSerial != existingParts.msgSerial) {
    return incomingParts.msgSerial > existingParts.msgSerial;
  }
  return incomingParts.index > existingParts.index;
}

/// A message is "synthesized" if its connectionId is not an initial substring
/// of its id, or if id is null.
bool _isSynthesized(PresenceMessage message) {
  if (message.id == null || message.connectionId == null) return true;
  return !message.id!.startsWith(message.connectionId!);
}

/// Parsed components of a presence message id.
class _IdParts {
  _IdParts(this.msgSerial, this.index);
  final int msgSerial;
  final int index;
}

/// Parses a message id of the form `connectionId:msgSerial:index`.
_IdParts _parseId(String id, String connectionId) {
  // id format: "connectionId:msgSerial:index"
  // Strip the connectionId prefix and colon
  final suffix = id.substring(connectionId.length + 1);
  final parts = suffix.split(':');
  return _IdParts(
    int.parse(parts[0]),
    parts.length > 1 ? int.parse(parts[1]) : 0,
  );
}

/// Maintains a map of members currently present on a channel.
///
/// Keyed by memberKey (`connectionId:clientId`). Stores PresenceMessage values
/// with action set to PRESENT (or ABSENT during sync).
///
/// Spec: RTP2
class PresenceMap {
  final Map<String, PresenceMessage> _map = {};
  Set<String>? _residualMembers;
  bool _syncInProgress = false;

  /// Whether a sync operation is currently in progress.
  bool get isSyncInProgress => _syncInProgress;

  /// Adds or updates a member in the presence map.
  ///
  /// Returns the message to emit to subscribers (with original action), or
  /// null if the message is stale (RTP2a).
  ///
  /// The stored copy has action set to PRESENT (RTP2d2). The returned copy
  /// preserves the original action for emission (RTP2d1).
  PresenceMessage? put(PresenceMessage message) {
    final key = message.memberKey;

    // Remove from residual set if sync in progress.
    // This must happen before the newness check — even if the incoming
    // message is stale, the member has been "seen" during sync and must
    // not be evicted as residual on endSync (matches ably-js behaviour).
    _residualMembers?.remove(key);

    // Check newness against existing entry (RTP2a)
    final existing = _map[key];
    if (existing != null && !_isNewer(message, existing)) {
      return null; // Stale message, reject
    }

    // Store with action=PRESENT (RTP2d2)
    _map[key] = message.copyWith(action: PresenceAction.present);

    // Return with original action for emission (RTP2d1)
    return message;
  }

  /// Processes a LEAVE message for a member.
  ///
  /// Outside sync: removes the member and returns a LEAVE message to emit
  /// (RTP2h1a, RTP2h1b). Returns null if no matching member exists.
  ///
  /// During sync: stores the member as ABSENT (RTP2h2a) and returns null
  /// (the leave will be emitted on endSync if the member is still absent).
  PresenceMessage? remove(PresenceMessage message) {
    final key = message.memberKey;
    final existing = _map[key];

    if (existing == null && !_syncInProgress) {
      return null; // No member to remove
    }

    // Check newness if there's an existing entry
    if (existing != null && !_isNewer(message, existing)) {
      return null; // Stale message, reject
    }

    // Remove from residual set if sync in progress
    _residualMembers?.remove(key);

    if (_syncInProgress) {
      // RTP2h2a: during sync, store as ABSENT
      _map[key] = message.copyWith(action: PresenceAction.absent);
      return null;
    } else {
      // RTP2h1b: outside sync, delete from map
      _map.remove(key);
      // RTP2h1a: return LEAVE for emission
      return message;
    }
  }

  /// Returns the presence message for the given memberKey, or null.
  PresenceMessage? get(String memberKey) => _map[memberKey];

  /// Returns all PRESENT members (excludes ABSENT members).
  List<PresenceMessage> values() =>
      _map.values.where((m) => m.action != PresenceAction.absent).toList();

  /// Clears all members and resets sync state.
  void clear() {
    _map.clear();
    _residualMembers = null;
    _syncInProgress = false;
  }

  /// Starts a sync operation (RTP18a).
  ///
  /// Takes a snapshot of current memberKeys as residual members. Members
  /// seen during sync (via put) are removed from the residual set.
  void startSync() {
    _residualMembers = Set<String>.from(_map.keys);
    _syncInProgress = true;
  }

  /// Ends a sync operation (RTP18b, RTP19).
  ///
  /// Removes ABSENT members (RTP2h2b). For each residual member (present at
  /// start of sync but not seen during sync), creates a synthesized LEAVE
  /// event with id=null and timestamp=now (RTP19).
  ///
  /// Returns the list of synthesized LEAVE events to emit.
  List<PresenceMessage> endSync() {
    if (!_syncInProgress) {
      return [];
    }

    final leaveEvents = <PresenceMessage>[];
    final now = DateTime.now();

    // RTP2h2b: delete all ABSENT members
    _map.removeWhere((key, msg) => msg.action == PresenceAction.absent);

    // RTP19: synthesize LEAVE events for residual members
    if (_residualMembers != null) {
      for (final key in _residualMembers!) {
        final member = _map[key];
        if (member != null) {
          leaveEvents.add(
            member.copyWith(
              action: PresenceAction.leave,
              clearId: true,
              timestamp: now,
            ),
          );
          _map.remove(key);
        }
      }
    }

    _residualMembers = null;
    _syncInProgress = false;

    return leaveEvents;
  }
}

/// Maintains a map of members entered by the current connection.
///
/// Used for automatic re-entry (RTP17i, RTP17g) when the channel reattaches.
/// Keyed by clientId only (RTP17h), not by memberKey.
///
/// Spec: RTP17
class LocalPresenceMap {
  final Map<String, PresenceMessage> _map = {};

  /// Adds or updates a member in the local presence map.
  ///
  /// Unlike PresenceMap, does not perform newness comparison and preserves
  /// the original action.
  void put(PresenceMessage message) {
    _map[message.clientId!] = message;
  }

  /// Processes a LEAVE message for a member.
  ///
  /// Returns true if the member was removed (non-synthesized leave).
  /// Returns false if the leave was synthesized and ignored (RTP17b).
  ///
  /// A leave is synthesized when connectionId is NOT an initial substring
  /// of its id (per RTP2b1).
  bool remove(PresenceMessage message) {
    if (_isSynthesized(message)) {
      return false; // Synthesized leave, ignore (RTP17b)
    }
    _map.remove(message.clientId);
    return true;
  }

  /// Returns the presence message for the given clientId, or null.
  PresenceMessage? get(String clientId) => _map[clientId];

  /// Returns all members in the local presence map.
  List<PresenceMessage> values() => _map.values.toList();

  /// Clears all members.
  void clear() {
    _map.clear();
  }
}
