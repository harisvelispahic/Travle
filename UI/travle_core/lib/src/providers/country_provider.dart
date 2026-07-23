import '../models/country_response.dart';
import '../network/base_provider.dart';

/// Reads countries (`GET /Countries`). Reads require an authenticated user;
/// writes are admin-only (desktop reference CRUD). Top of the location cascade.
class CountryProvider extends BaseProvider<CountryResponse> {
  CountryProvider() : super('Countries');

  @override
  CountryResponse fromJson(Map<String, dynamic> json) =>
      CountryResponse.fromJson(json);
}
