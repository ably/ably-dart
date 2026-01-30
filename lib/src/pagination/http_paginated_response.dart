import 'paginated_result.dart';

/// A paginated result with HTTP response metadata.
abstract class HttpPaginatedResponse<T> extends PaginatedResult<T> {
  /// The HTTP status code.
  int? get statusCode;

  /// Whether the response indicates success (2xx status code).
  bool? get success;

  /// The Ably error code from the X-Ably-Errorcode header.
  int? get errorCode;

  /// The error message from the X-Ably-Errormessage header.
  String? get errorMessage;

  /// Response headers.
  List<Map<String, String>>? get headers;

  @override
  Future<HttpPaginatedResponse<T>?> next();

  @override
  Future<HttpPaginatedResponse<T>> first();
}
