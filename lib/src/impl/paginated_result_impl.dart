import '../message/annotation.dart';
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

/// Function type for fetching HTTP paginated results.
typedef HttpPageFetcher<T> = Future<HttpPaginatedResponse<T>> Function(
    String url);

/// Type-specific parsers for paginated results.
class PaginatedResultParser {
  /// Parses a list of messages from JSON.
  static List<Message> parseMessages(dynamic body) {
    if (body == null) return [];
    if (body is! List) return [];
    return body.cast<Map<String, dynamic>>().map(Message.fromMap).toList();
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

  /// Parses a list of annotations from JSON.
  static List<Annotation> parseAnnotations(dynamic body) {
    if (body == null) return [];
    if (body is! List) return [];
    return body.cast<Map<String, dynamic>>().map(Annotation.fromMap).toList();
  }
}
