import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

const _proxyVersion = 'v0.1.0';
const _proxyRepo = 'ably/uts-proxy';

const _controlPort = 9100;
const _controlHost = 'http://localhost:$_controlPort';

const _sandboxRealtimeHost = 'sandbox-realtime.ably.io';
const _sandboxRestHost = 'sandbox-rest.ably.io';

const _checksums = {
  'uts-proxy_darwin_amd64.tar.gz':
      'eb8abf5eec7f7137cf9e7cb6ab6f45fd162303c242b4567ab9e354c4b9a4a4ff',
  'uts-proxy_darwin_arm64.tar.gz':
      '845da80af7d5b1daacbdf30b34aff6ca1b2bb88c708065bdc5d9a636baf32a1f',
  'uts-proxy_linux_amd64.tar.gz':
      '79f444c23362cc277d163deb243dc16063c74665ff63b8bd3e56789b9d9610c7',
  'uts-proxy_linux_arm64.tar.gz':
      '7357e4605f19451d83bb419ee959537d6e95ca74b766721eae006d4171371030',
};

String _cacheDir() {
  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '.';
  return '$home/.cache/uts-proxy/$_proxyVersion';
}

String _proxyBinPath() => '${_cacheDir()}/uts-proxy';

String _assetName() {
  final platform = Platform.isMacOS ? 'darwin' : 'linux';
  final arch = _isArm64() ? 'arm64' : 'amd64';
  return 'uts-proxy_${platform}_$arch.tar.gz';
}

bool _isArm64() {
  if (Platform.isMacOS) {
    final result = Process.runSync('uname', ['-m']);
    return result.stdout.toString().trim() == 'arm64';
  }
  return Platform.version.contains('arm64');
}

Future<void> _downloadProxy() async {
  final binPath = _proxyBinPath();
  if (File(binPath).existsSync()) return;

  final asset = _assetName();
  final expectedHash = _checksums[asset];
  if (expectedHash == null) {
    throw StateError('No checksum for $asset — unsupported platform/arch');
  }

  final cacheDir = _cacheDir();
  Directory(cacheDir).createSync(recursive: true);

  final url = 'https://github.com/$_proxyRepo/releases/download/'
      '$_proxyVersion/$asset';
  stderr.writeln('Downloading uts-proxy $_proxyVersion ($asset)...');

  final resp = await http.get(Uri.parse(url));
  if (resp.statusCode != 200) {
    throw StateError('Failed to download $url: ${resp.statusCode}');
  }

  final hash = sha256.convert(resp.bodyBytes).toString();
  if (hash != expectedHash) {
    throw StateError(
      'Checksum mismatch for $asset: expected $expectedHash, got $hash',
    );
  }

  // Extract to a temp directory, then move the binary into place.
  // Multiple isolates may race here — the final rename is atomic.
  final tmpDir = Directory.systemTemp.createTempSync('uts-proxy-');
  try {
    final tarball = '${tmpDir.path}/$asset';
    File(tarball).writeAsBytesSync(resp.bodyBytes);

    final result =
        await Process.run('tar', ['xzf', tarball], workingDirectory: tmpDir.path);
    if (result.exitCode != 0) {
      throw StateError('Failed to extract $asset: ${result.stderr}');
    }

    final extracted = File('${tmpDir.path}/uts-proxy');
    if (!extracted.existsSync()) {
      throw StateError('Binary not found after extraction');
    }

    // Atomic rename to final location. If another isolate already placed
    // it there, renameSync may fail on some platforms — fall back to copy.
    try {
      extracted.renameSync(binPath);
    } on FileSystemException {
      if (!File(binPath).existsSync()) rethrow;
    }

    await Process.run('chmod', ['+x', binPath]);
  } finally {
    tmpDir.deleteSync(recursive: true);
  }
}

int _nextPort = 19000 + Random().nextInt(1000);

int allocatePort() => _nextPort++;

Process? _proxyProcess;
bool _proxyEnsured = false;

/// Ensures the proxy process is running. Starts it if needed.
///
/// Downloads the binary from GitHub releases on first use, caching it
/// at `~/.cache/uts-proxy/<version>/uts-proxy`.
///
/// Safe to call from multiple test isolates — only one will start the
/// proxy; others will detect it via health check.
///
/// Call this in `setUpAll()` for proxy integration tests.
Future<void> ensureProxy({int timeoutMs = 15000}) async {
  if (_proxyEnsured) return;

  if (await _isProxyHealthy()) {
    _proxyEnsured = true;
    return;
  }

  await _downloadProxy();

  _proxyProcess = await Process.start(
    _proxyBinPath(),
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

/// No-op — the proxy is shared across test files and cleaned up on exit.
///
/// Retained for backward compatibility with existing tearDownAll() calls.
void stopProxy() {
  // The proxy process is managed at the test-runner level, not per-file.
  // Killing it here would break other test files running in parallel.
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
