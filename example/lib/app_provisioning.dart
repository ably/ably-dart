import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/retry.dart';

/// Used to provision the app with Ably sandbox environment
class AppProvisioning {
  /// Prefix of REST environment used to provision the app.
  String environmentPrefix;

  /// List of capabilities for the provisioned key
  Map<String, List<dynamic>> keyCapabilities;

  AppProvisioning({
    this.environmentPrefix = defaultEnvironmentPrefix,
    this.keyCapabilities = defaultKeyCapabilities,
  });

  static const String defaultEnvironmentPrefix = 'sandbox-';

  static const Map<String, List<dynamic>> defaultKeyCapabilities = {
    '*': [
      'publish',
      'subscribe',
      'history',
      'presence',
      'push-subscribe',
      'push-admin',
    ],
  };

  final http.Client _httpRetryClient = RetryClient(
    http.Client(),
    retries: 5,
    delay: (retryCount) => const Duration(seconds: 2),
  );

  String get _provisioningUrl =>
      'https://${environmentPrefix}rest.ably.io/apps';

  Map<String, String> get _requestHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Map<String, List<dynamic>> get _appSpec => {
        'namespaces': [
          {
            'id': 'pushenabled',
            'pushEnabled': true,
          }
        ],
        'keys': [
          {
            'capability': jsonEncode(keyCapabilities),
          },
        ],
      };

  Future<String> provisionApp() async {
    final response = await _httpRetryClient.post(
      Uri.parse(_provisioningUrl),
      body: jsonEncode(_appSpec),
      headers: _requestHeaders,
    );

    if (response.statusCode != HttpStatus.created) {
      log("Server didn't return success. ${response.body}");
      throw HttpException("Server didn't return success."
          ' Status: ${response.statusCode} : ${response.body}');
    }

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    return responseBody['keys'][0]['keyStr'] as String;
  }
}
