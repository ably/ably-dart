import 'paginated_result.dart';

/// A paginated HTTP response from the Ably REST API.
///
/// Provides access to response metadata in addition to the paginated items.
///
/// Spec: HP1-HP8, RSC19d
abstract class HttpPaginatedResponse<T> implements PaginatedResult<T> {
  /// The HTTP status code of the response.
  ///
  /// Spec: HP4
  int get statusCode;

  /// Whether the request was successful (2xx status code).
  ///
  /// Spec: HP5
  bool get success;

  /// The Ably error code from the X-Ably-Errorcode header, if present.
  ///
  /// Spec: HP6
  int? get errorCode;

  /// The error message from the X-Ably-Errormessage header, if present.
  ///
  /// Spec: HP7
  String? get errorMessage;

  /// All response headers.
  ///
  /// Spec: HP8
  Map<String, String> get headers;

  @override
  Future<HttpPaginatedResponse<T>?> next();

  @override
  Future<HttpPaginatedResponse<T>> first();
}

/// Implementation of HttpPaginatedResponse.
class HttpPaginatedResponseImpl<T> implements HttpPaginatedResponse<T> {
  HttpPaginatedResponseImpl({
    required this.items,
    required this.statusCode,
    required this.headers,
    required this.fetcher,
    this.firstUrl,
    this.nextUrl,
  });

  /// Creates an HttpPaginatedResponse from an HTTP response.
  factory HttpPaginatedResponseImpl.fromResponse({
    required int statusCode,
    required Map<String, String> headers,
    required List<T> items,
    required Future<HttpPaginatedResponse<T>> Function(String url) fetcher,
    String? firstUrl,
  }) {
    // Parse Link header for pagination
    final linkHeader = headers['link'];
    String? nextUrl;

    if (linkHeader != null) {
      // Parse Link: </path?cursor=xyz>; rel="next", </path>; rel="first"
      final links = linkHeader.split(',');
      for (final link in links) {
        final match =
            RegExp(r'<([^>]+)>;\s*rel="(\w+)"').firstMatch(link.trim());
        if (match != null) {
          final url = match.group(1);
          final rel = match.group(2);
          if (rel == 'next') {
            nextUrl = url;
          }
        }
      }
    }

    return HttpPaginatedResponseImpl(
      items: items,
      statusCode: statusCode,
      headers: headers,
      fetcher: fetcher,
      firstUrl: firstUrl,
      nextUrl: nextUrl,
    );
  }

  @override
  final List<T> items;

  @override
  final int statusCode;

  @override
  final Map<String, String> headers;

  /// Function to fetch the next page.
  final Future<HttpPaginatedResponse<T>> Function(String url) fetcher;

  /// URL for the first page.
  final String? firstUrl;

  /// URL for the next page.
  final String? nextUrl;

  @override
  bool get success => statusCode >= 200 && statusCode < 300;

  @override
  int? get errorCode {
    final code = headers['x-ably-errorcode'];
    return code != null ? int.tryParse(code) : null;
  }

  @override
  String? get errorMessage => headers['x-ably-errormessage'];

  @override
  bool hasNext() => nextUrl != null;

  @override
  bool isLast() => !hasNext();

  @override
  Future<HttpPaginatedResponse<T>?> next() async {
    if (nextUrl == null) return null;
    return fetcher(nextUrl!);
  }

  @override
  Future<HttpPaginatedResponse<T>> first() async {
    if (firstUrl == null) {
      throw StateError('First URL not available');
    }
    return fetcher(firstUrl!);
  }
}
