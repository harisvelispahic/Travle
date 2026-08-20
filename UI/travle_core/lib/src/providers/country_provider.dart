import '../models/country_response.dart';
import '../network/base_provider.dart';

/// Reads countries (`GET /Countries`). Reads require an authenticated user;
/// writes are admin-only (desktop reference CRUD). Top of the location cascade.
class CountryProvider extends BaseProvider<CountryResponse> {
  CountryProvider() : super('Countries');

  /// The API's hard page-size ceiling (`BaseReadService.MaxPageSize`).
  static const int _maxPageSize = 100;

  @override
  CountryResponse fromJson(Map<String, dynamic> json) =>
      CountryResponse.fromJson(json);

  /// Every country, name-sorted.
  ///
  /// The seeded reference set is ~190 countries and the API caps a page at 100,
  /// so a single `get(pageSize: 100)` silently returns a bit over half the list.
  /// That is not just a short menu: a form prefilled with a country from the
  /// missing half hands `DropdownButtonFormField` a value none of its items carry,
  /// which trips DropdownButton's "exactly one item with this value" assertion.
  /// Every country picker in either app must therefore go through here rather than
  /// fetching one page. Region and city lists are always scoped to a parent and
  /// comfortably fit one page, so they have no equivalent.
  Future<List<CountryResponse>> getAll() async {
    final all = <CountryResponse>[];
    var page = 1;
    while (true) {
      final result = await get(filter: {
        'page': page,
        'pageSize': _maxPageSize,
        'sortBy': 'Name',
        'includeTotalCount': false,
      });
      all.addAll(result.items);
      if (result.items.length < _maxPageSize) break; // last page reached
      page++;
    }
    return all;
  }
}
