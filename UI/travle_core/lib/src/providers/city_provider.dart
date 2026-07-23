import '../models/city_response.dart';
import '../network/base_provider.dart';

/// Reads cities (`GET /Cities`). Filter by `regionId` to drive the
/// Region → City step of the location cascade. Reads require an authenticated
/// user; writes are admin-only (desktop reference CRUD).
class CityProvider extends BaseProvider<CityResponse> {
  CityProvider() : super('Cities');

  @override
  CityResponse fromJson(Map<String, dynamic> json) =>
      CityResponse.fromJson(json);
}
