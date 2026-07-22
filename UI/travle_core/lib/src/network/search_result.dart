/// Client mirror of the backend `PageResult<T>`: a page of [items] plus the
/// optional [totalCount] (present only when the request asked for it).
class SearchResult<T> {
  int? totalCount;
  List<T> items = <T>[];
}
