/// Base query object for list endpoints, mirroring the backend
/// `BaseSearchObject` (`Page`/`PageSize`/`IncludeTotalCount`/`SortBy`).
///
/// Subclass per entity and override [toJson] to add filters — remember to call
/// `super.toJson()` and merge. `null` values are omitted from the query string
/// by [BaseProvider]. Server caps `PageSize` at 100 regardless of what we send.
class BaseSearchObject {
  BaseSearchObject({
    this.page = 1,
    this.pageSize = 10,
    this.includeTotalCount = true,
    this.sortBy,
  });

  int? page;
  int? pageSize;
  bool? includeTotalCount;
  String? sortBy;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (page != null) 'page': page,
        if (pageSize != null) 'pageSize': pageSize,
        if (includeTotalCount != null) 'includeTotalCount': includeTotalCount,
        if (sortBy != null) 'sortBy': sortBy,
      };
}
