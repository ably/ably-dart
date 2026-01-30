import '../message/message.dart';
import '../message/presence_message.dart';
import '../pagination/http_paginated_response.dart';
import '../pagination/paginated_result.dart';
import 'http/http_client.dart';

/// Link header parser for pagination.
class LinkParser {
  static final _linkRegex = RegExp(r'<([^>]+)>;\s*rel="([^"]+)"');

  /// Parses a Link header into a map of rel -> url.
  static Map<String, String> parse(String? header) {
    final links = <String, String>{};
    if (header == null) return links;

    for (final match in _linkRegex.allMatches(header)) {
      final url = match.group(1);
      final rel = match.group(2);
      if (url != null && rel != null) {
        links[rel] = url;
      }
    }

    return links;
  }
}

/// Function type for fetching a page by URL.
typedef PageFetcher<T> = Future<PaginatedResult<T>> Function(String url);

/// Implementation of [PaginatedResult].
class PaginatedResultImpl<T> implements PaginatedResult<T> {
  PaginatedResultImpl({
    required List<T> items,
    required String? nextLink,
    required String? firstLink,
    required PageFetcher<T>? fetcher,
  })  : _items = List.unmodifiable(items),
        _nextLink = nextLink,
        _firstLink = firstLink,
        _fetcher = fetcher;

  final List<T> _items;
  final String? _nextLink;
  final String? _firstLink;
  final PageFetcher<T>? _fetcher;

  @override
  List<T> get items => _items;

  @override
  bool hasNext() => _nextLink != null;

  @override
  bool isLast() => !hasNext();

  @override
  Future<PaginatedResult<T>?> next() async {
    if (_nextLink == null || _fetcher == null) return null;
    return _fetcher!(_nextLink!);
  }

  @override
  Future<PaginatedResult<T>> first() async {
    if (_firstLink == null || _fetcher == null) {
      return this;
    }
    return _fetcher!(_firstLink!);
  }

  /// Creates a PaginatedResult from an HTTP response.
  static PaginatedResultImpl<T> fromResponse<T>({
    required AblyHttpResponse response,
    required List<T> items,
    required PageFetcher<T>? fetcher,
  }) {
    final links = LinkParser.parse(response.linkHeader);

    return PaginatedResultImpl<T>(
      items: items,
      nextLink: links['next'],
      firstLink: links['first'] ?? links['current'],
      fetcher: fetcher,
    );
  }
}

/// Implementation of [HttpPaginatedResponse].
class HttpPaginatedResponseImpl<T> implements HttpPaginatedResponse<T> {
  HttpPaginatedResponseImpl({
    required List<T> items,
    required this.statusCode,
    required this.errorCode,
    required this.errorMessage,
    required List<Map<String, String>>? headers,
    required String? nextLink,
    required String? firstLink,
    required PageFetcher<T>? fetcher,
  })  : _items = List.unmodifiable(items),
        _headers = headers,
        _nextLink = nextLink,
        _firstLink = firstLink,
        _fetcher = fetcher;

  final List<T> _items;
  final List<Map<String, String>>? _headers;
  final String? _nextLink;
  final String? _firstLink;
  final PageFetcher<T>? _fetcher;

  @override
  final int? statusCode;

  @override
  final int? errorCode;

  @override
  final String? errorMessage;

  @override
  bool? get success =>
      statusCode != null ? (statusCode! >= 200 && statusCode! < 300) : null;

  @override
  List<Map<String, String>>? get headers => _headers;

  @override
  List<T> get items => _items;

  @override
  bool hasNext() => _nextLink != null;

  @override
  bool isLast() => !hasNext();

  @override
  Future<HttpPaginatedResponse<T>?> next() async {
    if (_nextLink == null || _fetcher == null) return null;
    final result = await _fetcher!(_nextLink!);
    if (result is HttpPaginatedResponse<T>) {
      return result;
    }
    // Wrap in HttpPaginatedResponse if needed
    return HttpPaginatedResponseImpl<T>(
      items: result.items,
      statusCode: null,
      errorCode: null,
      errorMessage: null,
      headers: null,
      nextLink: result.hasNext() ? 'unknown' : null,
      firstLink: null,
      fetcher: _fetcher,
    );
  }

  @override
  Future<HttpPaginatedResponse<T>> first() async {
    if (_firstLink == null || _fetcher == null) {
      return this;
    }
    final result = await _fetcher!(_firstLink!);
    if (result is HttpPaginatedResponse<T>) {
      return result;
    }
    return HttpPaginatedResponseImpl<T>(
      items: result.items,
      statusCode: null,
      errorCode: null,
      errorMessage: null,
      headers: null,
      nextLink: result.hasNext() ? 'unknown' : null,
      firstLink: _firstLink,
      fetcher: _fetcher,
    );
  }

  /// Creates an HttpPaginatedResponse from an HTTP response.
  static HttpPaginatedResponseImpl<T> fromResponse<T>({
    required AblyHttpResponse response,
    required List<T> items,
    required PageFetcher<T>? fetcher,
  }) {
    final links = LinkParser.parse(response.linkHeader);

    // Convert headers to list format
    final headersList = response.headers.entries
        .map((e) => {e.key: e.value})
        .toList();

    return HttpPaginatedResponseImpl<T>(
      items: items,
      statusCode: response.statusCode,
      errorCode: response.errorCode,
      errorMessage: response.errorMessage,
      headers: headersList,
      nextLink: links['next'],
      firstLink: links['first'] ?? links['current'],
      fetcher: fetcher,
    );
  }
}

/// Type-specific parsers for paginated results.
class PaginatedResultParser {
  /// Parses a list of messages from JSON.
  static List<Message> parseMessages(dynamic body) {
    if (body == null) return [];
    if (body is! List) return [];
    return body
        .cast<Map<String, dynamic>>()
        .map(Message.fromMap)
        .toList();
  }

  /// Parses a list of presence messages from JSON.
  static List<PresenceMessage> parsePresenceMessages(dynamic body) {
    if (body == null) return [];
    if (body is! List) return [];
    return body
        .cast<Map<String, dynamic>>()
        .map(PresenceMessage.fromMap)
        .toList();
  }
}
