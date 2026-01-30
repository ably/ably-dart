import 'dart:convert';

import 'package:http/http.dart' as http;

/// A mock HTTP client for testing.
///
/// Captures outgoing requests and returns configurable responses.
class MockHttpClient extends http.BaseClient {
  final List<CapturedRequest> capturedRequests = [];
  final List<QueuedResponse> _queuedResponses = [];
  final Map<String, List<QueuedResponse>> _hostResponses = {};

  /// Queues a response to be returned for the next request.
  void queueResponse(
    int statusCode,
    Object body, {
    Map<String, String>? headers,
  }) {
    _queuedResponses.add(QueuedResponse(
      statusCode: statusCode,
      body: body,
      headers: headers ?? {},
    ));
  }

  /// Queues a response for a specific host.
  void queueResponseForHost(
    String host,
    int statusCode,
    Object body, {
    Map<String, String>? headers,
  }) {
    _hostResponses.putIfAbsent(host, () => []);
    _hostResponses[host]!.add(QueuedResponse(
      statusCode: statusCode,
      body: body,
      headers: headers ?? {},
    ));
  }

  /// Resets all queued responses and captured requests.
  void reset() {
    capturedRequests.clear();
    _queuedResponses.clear();
    _hostResponses.clear();
  }

  /// Gets captured requests for a specific host.
  List<CapturedRequest> capturedRequestsForHost(String host) {
    return capturedRequests.where((r) => r.url.host == host).toList();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final capturedRequest = CapturedRequest(
      method: request.method,
      url: request.url,
      headers: Map.from(request.headers),
      body: request is http.Request ? request.body : null,
    );
    capturedRequests.add(capturedRequest);

    // Check for host-specific response
    final host = request.url.host;
    if (_hostResponses.containsKey(host) && _hostResponses[host]!.isNotEmpty) {
      return _createResponse(_hostResponses[host]!.removeAt(0));
    }

    // Use general queue
    if (_queuedResponses.isNotEmpty) {
      return _createResponse(_queuedResponses.removeAt(0));
    }

    // Default 200 OK response
    return _createResponse(QueuedResponse(
      statusCode: 200,
      body: {},
      headers: {'Content-Type': 'application/json'},
    ));
  }

  http.StreamedResponse _createResponse(QueuedResponse response) {
    final body = response.body;
    final String bodyString;

    if (body is String) {
      bodyString = body;
    } else {
      bodyString = json.encode(body);
    }

    final headers = Map<String, String>.from(response.headers);
    headers.putIfAbsent('Content-Type', () => 'application/json');

    return http.StreamedResponse(
      Stream.value(utf8.encode(bodyString)),
      response.statusCode,
      headers: headers,
    );
  }
}

/// A captured HTTP request for inspection.
class CapturedRequest {
  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String? body;

  CapturedRequest({
    required this.method,
    required this.url,
    required this.headers,
    this.body,
  });

  /// Parses the body as JSON.
  dynamic get jsonBody => body != null ? json.decode(body!) : null;
}

/// A queued response configuration.
class QueuedResponse {
  final int statusCode;
  final Object body;
  final Map<String, String> headers;
  final Duration? delay;

  QueuedResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
    this.delay,
  });
}
