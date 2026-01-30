import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// A mock HTTP client for testing.
///
/// Captures outgoing requests and returns configurable responses.
/// Supports error simulation (network errors, timeouts) for fallback testing.
class MockHttpClient extends http.BaseClient {
  final List<CapturedRequest> capturedRequests = [];
  final List<QueuedResponse> _queuedResponses = [];
  final Map<String, List<QueuedResponse>> _hostResponses = {};
  final List<_QueuedError> _queuedErrors = [];
  final Map<String, List<_QueuedError>> _hostErrors = {};

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

  /// Queues a delayed response.
  void queueDelayedResponse(
    Duration delay,
    int statusCode,
    Object body, {
    Map<String, String>? headers,
  }) {
    _queuedResponses.add(QueuedResponse(
      statusCode: statusCode,
      body: body,
      headers: headers ?? {},
      delay: delay,
    ));
  }

  /// Queues a network error (e.g., connection refused, DNS failure).
  void queueNetworkError([String message = 'Network error']) {
    _queuedErrors.add(_QueuedError(
      type: _ErrorType.network,
      message: message,
    ));
  }

  /// Queues a network error for a specific host.
  void queueNetworkErrorForHost(String host, [String message = 'Network error']) {
    _hostErrors.putIfAbsent(host, () => []);
    _hostErrors[host]!.add(_QueuedError(
      type: _ErrorType.network,
      message: message,
    ));
  }

  /// Queues a timeout error.
  void queueTimeout([Duration duration = const Duration(seconds: 30)]) {
    _queuedErrors.add(_QueuedError(
      type: _ErrorType.timeout,
      message: 'Request timed out',
      duration: duration,
    ));
  }

  /// Queues a timeout error for a specific host.
  void queueTimeoutForHost(String host, [Duration duration = const Duration(seconds: 30)]) {
    _hostErrors.putIfAbsent(host, () => []);
    _hostErrors[host]!.add(_QueuedError(
      type: _ErrorType.timeout,
      message: 'Request timed out',
      duration: duration,
    ));
  }

  /// Resets all queued responses and captured requests.
  void reset() {
    capturedRequests.clear();
    _queuedResponses.clear();
    _hostResponses.clear();
    _queuedErrors.clear();
    _hostErrors.clear();
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

    final host = request.url.host;

    // Check for host-specific error first
    if (_hostErrors.containsKey(host) && _hostErrors[host]!.isNotEmpty) {
      return _handleError(_hostErrors[host]!.removeAt(0));
    }

    // Check for general queued error
    if (_queuedErrors.isNotEmpty) {
      return _handleError(_queuedErrors.removeAt(0));
    }

    // Check for host-specific response
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

  Future<http.StreamedResponse> _handleError(_QueuedError error) async {
    switch (error.type) {
      case _ErrorType.network:
        throw SocketException(error.message);
      case _ErrorType.timeout:
        throw TimeoutException(error.message, error.duration);
    }
  }

  Future<http.StreamedResponse> _createResponse(QueuedResponse response) async {
    // Apply delay if specified
    if (response.delay != null) {
      await Future.delayed(response.delay!);
    }

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

/// Internal error type for mock error simulation.
enum _ErrorType { network, timeout }

/// Internal class for queued errors.
class _QueuedError {
  final _ErrorType type;
  final String message;
  final Duration? duration;

  _QueuedError({
    required this.type,
    required this.message,
    this.duration,
  });
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
