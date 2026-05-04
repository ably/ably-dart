/// A page of results from a paginated query.
///
/// Spec: TG
abstract class PaginatedResult<T> {
  /// The items in this page.
  ///
  /// Spec: TG1
  List<T> get items;

  /// Whether there are more pages after this one.
  ///
  /// Spec: TG2
  bool hasNext();

  /// Whether this is the last page.
  ///
  /// Spec: TG2
  bool isLast() => !hasNext();

  /// Fetches the next page of results.
  ///
  /// Returns null if this is the last page.
  ///
  /// Spec: TG3
  Future<PaginatedResult<T>?> next();

  /// Fetches the first page of results.
  ///
  /// Spec: TG4
  Future<PaginatedResult<T>> first();
}
