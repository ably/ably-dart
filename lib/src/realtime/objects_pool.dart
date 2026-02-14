import 'live_counter.dart';
import 'live_map.dart';
import 'live_object.dart';
import 'object_message.dart';

/// Sync state for the objects on a channel.
///
/// Spec: RTO17a
enum ObjectsSyncState {
  /// Initial state.
  ///
  /// Spec: RTO17a1
  initialized,

  /// Syncing with the Ably service.
  ///
  /// Spec: RTO17a2
  syncing,

  /// Synced with the Ably service.
  ///
  /// Spec: RTO17a3
  synced,
}

/// Manages the collection of LiveObject instances for a channel.
///
/// Handles the sync state machine (INITIALIZED → SYNCING → SYNCED),
/// processes OBJECT_SYNC messages, buffers OBJECT messages during sync,
/// applies operations in SYNCED state, creates zero-value objects on demand,
/// and garbage collects tombstoned objects.
///
/// Spec: RTO3
class ObjectsPool {
  /// Creates a new ObjectsPool with a root LiveMap.
  ///
  /// Spec: RTO3b1
  ObjectsPool() {
    _objects['root'] = LiveMap(objectId: 'root');
  }

  /// The pool of all LiveObject instances, keyed by objectId.
  ///
  /// Spec: RTO3a
  final Map<String, LiveObject> _objects = {};

  /// Current sync state.
  ///
  /// Spec: RTO17
  ObjectsSyncState syncState = ObjectsSyncState.initialized;

  /// Buffered OBJECT messages received during sync.
  ///
  /// Spec: RTO7a
  final List<ObjectMessage> bufferedObjectOperations = [];

  /// Temporary storage for ObjectStates during sync sequence.
  ///
  /// Internal SyncObjectsPool.
  final List<ObjectState> _syncObjectsPool = [];

  /// Current sync sequence identifier.
  String? _currentSyncSequenceId;

  /// Callback for update events (objectId, update).
  void Function(LiveObject object, LiveObjectUpdate update)? onUpdate;

  /// Returns a LiveObject by objectId, or null.
  LiveObject? getObject(String objectId) => _objects[objectId];

  /// Handle an ATTACHED ProtocolMessage.
  ///
  /// Spec: RTO4
  void handleAttached({required bool hasObjectsFlag}) {
    // RTO4c: Transition to SYNCING
    if (syncState != ObjectsSyncState.syncing) {
      syncState = ObjectsSyncState.syncing;
    }

    if (hasObjectsFlag) {
      // RTO4a: Server will perform OBJECT_SYNC
      return;
    }

    // RTO4b: No HAS_OBJECTS — complete sync immediately

    // RTO4b1: Remove all objects except root
    _objects.removeWhere((id, _) => id != 'root');

    // RTO4b2: Clear root data
    final root = _objects['root']! as LiveMap;
    final previousKeys = root.keys().toList();
    root.setZeroValue();

    // RTO4b2a: Emit update for cleared root
    if (previousKeys.isNotEmpty) {
      final removedUpdate = <String, String>{};
      for (final key in previousKeys) {
        removedUpdate[key] = 'removed';
      }
      onUpdate?.call(root, LiveMapUpdate(update: removedUpdate));
    }

    // RTO4b3: Clear SyncObjectsPool
    _syncObjectsPool.clear();

    // RTO4b5: Clear buffered operations
    bufferedObjectOperations.clear();

    // RTO4b4: Perform sync completion actions
    _completeSyncActions();
  }

  /// Handle an OBJECT_SYNC ProtocolMessage.
  ///
  /// Spec: RTO5
  void handleObjectSync({
    String? channelSerial,
    List<ObjectState>? objectStates,
  }) {
    // RTO5e: Transition to SYNCING if not already
    if (syncState != ObjectsSyncState.syncing) {
      syncState = ObjectsSyncState.syncing;
    }

    // RTO5a5: No channelSerial — self-contained sync
    if (channelSerial == null) {
      _syncObjectsPool.clear();
      bufferedObjectOperations.clear();
      _currentSyncSequenceId = null;

      // RTO5d: Skip if objectStates is null
      if (objectStates != null) {
        // RTO5b: Store object states
        _syncObjectsPool.addAll(objectStates);
      }

      // Self-contained, complete immediately
      _completeSyncActions();
      return;
    }

    // RTO5a1: Parse channelSerial as "sequenceId:cursor"
    final colonIndex = channelSerial.indexOf(':');
    final sequenceId = colonIndex >= 0
        ? channelSerial.substring(0, colonIndex)
        : channelSerial;
    final cursor =
        colonIndex >= 0 ? channelSerial.substring(colonIndex + 1) : '';

    // RTO5a2: New sequence id — discard previous sync
    if (_currentSyncSequenceId != null &&
        sequenceId != _currentSyncSequenceId) {
      _syncObjectsPool.clear();
      bufferedObjectOperations.clear();
    }
    _currentSyncSequenceId = sequenceId;

    // RTO5d: Skip if objectStates is null
    if (objectStates != null) {
      // RTO5b: Store object states
      _syncObjectsPool.addAll(objectStates);
    }

    // RTO5a4: Sync complete when cursor is empty
    if (cursor.isEmpty) {
      _completeSyncActions();
    }
  }

  /// Perform sync completion actions.
  ///
  /// Spec: RTO5c
  void _completeSyncActions() {
    final syncedObjectIds = <String>{};
    final pendingUpdates = <(LiveObject, LiveObjectUpdate)>[];

    // RTO5c1: Process each ObjectState
    for (final objectState in _syncObjectsPool) {
      syncedObjectIds.add(objectState.objectId);

      final existing = _objects[objectState.objectId];
      if (existing != null) {
        // RTO5c1a: Object exists — replace data
        final update = _replaceObjectData(existing, objectState);
        if (update != null) {
          // RTO5c1a2: Store update for later emission
          pendingUpdates.add((existing, update));
        }
      } else {
        // RTO5c1b: Object doesn't exist — create from state
        _createObjectFromState(objectState);
      }
    }

    // RTO5c2: Remove objects not in sync (except root)
    _objects.removeWhere(
      (id, _) => id != 'root' && !syncedObjectIds.contains(id),
    );

    // RTO5c7: Emit stored updates
    for (final (object, update) in pendingUpdates) {
      if (!update.noop) {
        onUpdate?.call(object, update);
      }
    }

    // RTO5c6: Apply buffered operations
    _applyMessages(bufferedObjectOperations);

    // RTO5c3: Clear sync identifiers
    _currentSyncSequenceId = null;

    // RTO5c4: Clear SyncObjectsPool
    _syncObjectsPool.clear();

    // RTO5c5: Clear buffered operations
    bufferedObjectOperations.clear();

    // RTO5c8: Transition to SYNCED
    syncState = ObjectsSyncState.synced;
  }

  /// Replace data on an existing object from an ObjectState.
  LiveObjectUpdate? _replaceObjectData(LiveObject object, ObjectState state) {
    // Build a dummy outer ObjectMessage for tombstone timestamp
    final outerMessage = ObjectMessage(
      serial: state.siteTimeserials.values.isNotEmpty
          ? state.siteTimeserials.values.first
          : '',
      siteCode: state.siteTimeserials.keys.isNotEmpty
          ? state.siteTimeserials.keys.first
          : '',
    );

    if (object is LiveCounter) {
      return object.replaceData(state, outerMessage);
    } else if (object is LiveMap) {
      return object.replaceData(state, outerMessage);
    }
    return null;
  }

  /// Create a new LiveObject from an ObjectState.
  ///
  /// Spec: RTO5c1b
  void _createObjectFromState(ObjectState objectState) {
    final outerMessage = ObjectMessage(
      serial: objectState.siteTimeserials.values.isNotEmpty
          ? objectState.siteTimeserials.values.first
          : '',
      siteCode: objectState.siteTimeserials.keys.isNotEmpty
          ? objectState.siteTimeserials.keys.first
          : '',
    );

    if (objectState.counter != null) {
      // RTO5c1b1a: Create LiveCounter
      final counter = LiveCounter(objectId: objectState.objectId);
      counter.replaceData(objectState, outerMessage);
      _objects[objectState.objectId] = counter;
    } else if (objectState.map != null) {
      // RTO5c1b1b: Create LiveMap
      final map = LiveMap(objectId: objectState.objectId);
      map.replaceData(objectState, outerMessage);
      _objects[objectState.objectId] = map;
    }
    // RTO5c1b1c: Otherwise, unsupported — skip
  }

  /// Handle OBJECT ProtocolMessage(s).
  ///
  /// Spec: RTO8
  void handleObjectMessage(List<ObjectMessage> messages) {
    // RTO8a: If not SYNCED, buffer
    if (syncState != ObjectsSyncState.synced) {
      bufferedObjectOperations.addAll(messages);
      return;
    }

    // RTO8b: Apply directly
    _applyMessages(messages);
  }

  /// Apply a list of ObjectMessages to the pool.
  ///
  /// Spec: RTO9
  void _applyMessages(List<ObjectMessage> messages) {
    for (final message in messages) {
      // RTO9a1: Skip if operation is null
      if (message.operation == null) continue;

      final action = message.operation!.action;

      // RTO9a2a: Supported actions
      if (action == ObjectOperationAction.mapCreate ||
          action == ObjectOperationAction.mapSet ||
          action == ObjectOperationAction.mapRemove ||
          action == ObjectOperationAction.mapClear ||
          action == ObjectOperationAction.counterCreate ||
          action == ObjectOperationAction.counterInc ||
          action == ObjectOperationAction.objectDelete) {
        final objectId = message.operation!.objectId;

        // RTO9a2a1, RTO6: Create zero-value object if needed
        _createZeroValueIfNeeded(objectId);

        // RTO9a2a2: Get object
        final object = _objects[objectId];
        if (object == null) continue;

        // RTO9a2a3: Apply operation
        final update = object.applyOperation(message);
        if (update != null && !update.noop) {
          onUpdate?.call(object, update);
        }
      }
      // RTO9a2b: Unsupported action — skip
    }
  }

  /// Create a zero-value object if one doesn't exist for the given objectId.
  ///
  /// Spec: RTO6
  void _createZeroValueIfNeeded(String objectId) {
    // RTO6a: If already exists, don't create
    if (_objects.containsKey(objectId)) return;

    // RTO6b: Infer type from objectId prefix
    final colonIndex = objectId.indexOf(':');
    if (colonIndex < 0) return;

    final type = objectId.substring(0, colonIndex);

    switch (type) {
      // RTO6b2: map prefix
      case 'map':
        _objects[objectId] = LiveMap(objectId: objectId);
      // RTO6b3: counter prefix
      case 'counter':
        _objects[objectId] = LiveCounter(objectId: objectId);
    }
  }

  /// Garbage collect tombstoned objects and entries past grace period.
  ///
  /// Spec: RTO10
  void gc({required int currentTime, required int gracePeriod}) {
    final keysToRemove = <String>[];

    for (final entry in _objects.entries) {
      // RTO10c1a: Check if LiveMap needs entry GC
      if (entry.value is LiveMap) {
        (entry.value as LiveMap).gcTombstonedEntries(
          currentTime: currentTime,
          gracePeriod: gracePeriod,
        );
      }

      // RTO10c1b: Check if object is tombstoned past grace period
      if (entry.value.isTombstone &&
          entry.value.tombstonedAt != null &&
          (currentTime - entry.value.tombstonedAt!) >= gracePeriod) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _objects.remove(key);
    }
  }
}
