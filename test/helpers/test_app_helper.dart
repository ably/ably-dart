import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Shared helper for provisioning and tearing down Ably sandbox test apps.
///
/// Uses the canonical test-app-setup.json from the ably-common submodule
/// (submodules/test-resources/test-app-setup.json) to provision apps with
/// a standardised set of keys, namespaces, and channels.
///
/// Key indices (from test-app-setup.json):
///   0 — full access (default capability)
///   1 — restricted: cansubscribe, canpublish, pushenabled capabilities
///   2 — restricted: channel0–channel6 with varying capabilities
///   3 — subscribe-only: {"*":["subscribe"]}
///   4 — revocableTokens: true
///   5 — wildcard: {"[*]*":["*"]}
class TestApp {
  TestApp._({
    required this.appId,
    required this.keys,
  });

  /// The app ID.
  final String appId;

  /// The provisioned keys.
  final List<TestAppKey> keys;

  /// The sandbox REST host (nonprod environment per REC1b3).
  static const String sandboxRestHost = 'sandbox.realtime.ably-nonprod.net';

  /// Provisions a new sandbox app using the ably-common test-app-setup.json.
  static Future<TestApp> provision() async {
    final setupJson = _loadTestAppSetup();
    final postApps = setupJson['post_apps'];

    final response = await http.post(
      Uri.parse('https://$sandboxRestHost/apps'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(postApps),
    );

    if (response.statusCode != 201) {
      throw Exception(
        'Failed to provision sandbox app: '
        '${response.statusCode} ${response.body}',
      );
    }

    final appConfig = jsonDecode(response.body) as Map<String, dynamic>;
    final appId = appConfig['appId'] as String;
    final keys = (appConfig['keys'] as List)
        .map((k) => TestAppKey.fromMap(k as Map<String, dynamic>))
        .toList();

    return TestApp._(appId: appId, keys: keys);
  }

  /// Deletes this app from the sandbox.
  Future<void> delete() async {
    final authBytes = utf8.encode(keys[0].keyStr);
    final authHeader = 'Basic ${base64Encode(authBytes)}';

    await http.delete(
      Uri.parse('https://$sandboxRestHost/apps/$appId'),
      headers: {'Authorization': authHeader},
    );
  }

  static Map<String, dynamic> _loadTestAppSetup() {
    // Find the submodules directory relative to the test runner's working dir.
    // When running `dart test` from the ably-dart directory, the working
    // directory is the ably-dart root.
    final candidates = [
      'submodules/ably-common/test-resources/test-app-setup.json',
      '../submodules/ably-common/test-resources/test-app-setup.json',
    ];

    for (final path in candidates) {
      final file = File(path);
      if (file.existsSync()) {
        return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      }
    }

    throw Exception(
      'Could not find test-app-setup.json. '
      'Ensure the ably-common submodule is initialised: '
      'git submodule update --init',
    );
  }
}

/// A key provisioned as part of a test app.
class TestAppKey {
  const TestAppKey({
    required this.keyStr,
    required this.keyName,
    required this.keySecret,
    required this.capability,
  });

  factory TestAppKey.fromMap(Map<String, dynamic> map) {
    return TestAppKey(
      keyStr: map['keyStr'] as String,
      keyName: map['keyName'] as String,
      keySecret: map['keySecret'] as String,
      capability: map['capability'] as String? ?? '{"*":["*"]}',
    );
  }

  /// The full key string (keyName:keySecret).
  final String keyStr;

  /// The key name (appId.keyId).
  final String keyName;

  /// The key secret.
  final String keySecret;

  /// The capability JSON string.
  final String capability;
}
