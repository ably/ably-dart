import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

const _controlPort = 9100;
const _controlHost = 'http://localhost:$_controlPort';

const _sandboxRealtimeHost = 'sandbox-realtime.ably.io';
const _sandboxRestHost = 'sandbox-rest.ably.io';

const _proxySourceDir = 'submodules/uts-proxy';
const _proxyBinPath = '$_proxySourceDir/test-proxy';

int _nextPort = 19000 + Random().nextInt(1000);

int allocatePort() => _nextPort++;

Future<void> _ensureProxyBinary() async {
  if (File(_proxyBinPath).existsSync()) return;

  if (!Directory(_proxySourceDir).existsSync()) {
    throw StateError(
      'uts-proxy submodule not found at $_proxySourceDir. '
      'Run: git submodule update --init',
    );
  }

  final result = await Process.run(
    'go',
    ['build', '-o', 'test-proxy', '.'],
    workingDirectory: _proxySourceDir,
  );
  if (result.exitCode != 0) {
    throw StateError(
      'Failed to build proxy (exit ${result.exitCode}): ${result.stderr}',
    );
  }
}

Process? _proxyProcess;
bool _proxyEnsured = false;

/// Ensures the proxy process is running. Starts it if needed.
///
/// Call this in `setUpAll()` for proxy integration tests.
Future<void> ensureProxy({int timeoutMs = 15000}) async {
  if (_proxyEnsured) return;

  // Check if already running (e.g. started externally)
  if (await _isProxyHealthy()) {
    _proxyEnsured = true;
    return;
  }

  await _ensureProxyBinary();

  _proxyProcess = await Process.start(
    _proxyBinPath,
    ['--port', '$_controlPort'],
    mode: ProcessStartMode.inheritStdio,
  );

  final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
  while (DateTime.now().isBefore(deadline)) {
    if (await _isProxyHealthy()) {
      _proxyEnsured = true;
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  _proxyProcess?.kill();
  _proxyProcess = null;
  throw StateError('Proxy failed to start within ${timeoutMs}ms');
}

/// Stops the proxy process if we started it.
///
/// Call this in `tearDownAll()`.
void stopProxy() {
  _proxyProcess?.kill();
  _proxyProcess = null;
  _proxyEnsured = false;
}

Future<bool> _isProxyHealthy() async {
  try {
    final resp = await http.get(Uri.parse('$_controlHost/health'));
    return resp.statusCode == 200;
  } catch (_) {
    return false;
  }
}

/// A proxy session wrapping the Go test proxy's control API.
class ProxySession {
  ProxySession._({
    required this.sessionId,
    required this.proxyHost,
    required this.proxyPort,
  });

  final String sessionId;
  final String proxyHost;
  final int proxyPort;

  /// Creates a new proxy session pointing at the Ably sandbox.
  static Future<ProxySession> create({
    int? port,
    List<Map<String, dynamic>>? rules,
    int? timeoutMs,
  }) async {
    final sessionPort = port ?? allocatePort();

    final body = <String, dynamic>{
      'target': {
        'realtimeHost': _sandboxRealtimeHost,
        'restHost': _sandboxRestHost,
      },
      'port': sessionPort,
      'rules': rules ?? [],
    };
    if (timeoutMs != null) {
      body['timeoutMs'] = timeoutMs;
    }

    final resp = await http.post(
      Uri.parse('$_controlHost/sessions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (resp.statusCode != 201) {
      throw StateError(
        'createProxySession failed (${resp.statusCode}): ${resp.body}',
      );
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return ProxySession._(
      sessionId: data['sessionId'] as String,
      proxyHost: 'localhost',
      proxyPort: sessionPort,
    );
  }

  /// Adds rules to this session.
  Future<void> addRules(
    List<Map<String, dynamic>> rules, {
    String position = 'append',
  }) async {
    final resp = await http.post(
      Uri.parse('$_controlHost/sessions/$sessionId/rules'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'rules': rules, 'position': position}),
    );
    if (resp.statusCode != 200) {
      throw StateError('addRules failed (${resp.statusCode}): ${resp.body}');
    }
  }

  /// Triggers an imperative action on the current active connection.
  Future<void> triggerAction(Map<String, dynamic> action) async {
    final resp = await http.post(
      Uri.parse('$_controlHost/sessions/$sessionId/actions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(action),
    );
    if (resp.statusCode != 200) {
      throw StateError(
        'triggerAction failed (${resp.statusCode}): ${resp.body}',
      );
    }
  }

  /// Retrieves the event log for this session.
  Future<List<Map<String, dynamic>>> getLog() async {
    final resp =
        await http.get(Uri.parse('$_controlHost/sessions/$sessionId/log'));
    if (resp.statusCode != 200) {
      throw StateError('getLog failed (${resp.statusCode}): ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final events = data['events'] as List<dynamic>? ?? [];
    return events.cast<Map<String, dynamic>>();
  }

  /// Deletes this session, stopping the proxy listener.
  Future<void> close() async {
    try {
      await http.delete(Uri.parse('$_controlHost/sessions/$sessionId'));
    } catch (_) {
      // Ignore cleanup errors
    }
  }
}
