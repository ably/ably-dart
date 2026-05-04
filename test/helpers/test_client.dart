import 'package:http/http.dart' as http;

import 'package:ably_dart/src/impl/base_client_impl.dart';
import 'package:ably_dart/ably_dart.dart';

/// A minimal client for testing shared BaseClientImpl functionality
/// (time, stats, request, etc.) without needing a full Rest or Realtime client.
class TestClient extends BaseClientImpl {
  TestClient({
    required super.options,
    super.httpClient,
  });
}
