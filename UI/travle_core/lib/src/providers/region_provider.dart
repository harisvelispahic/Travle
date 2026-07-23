import '../models/region_response.dart';
import '../network/base_provider.dart';

/// Reads regions (`GET /Regions`). Filter by `countryId` to drive the
/// Country → Region step of the location cascade. Reads require an authenticated
/// user; writes are admin-only (desktop reference CRUD).
class RegionProvider extends BaseProvider<RegionResponse> {
  RegionProvider() : super('Regions');

  @override
  RegionResponse fromJson(Map<String, dynamic> json) =>
      RegionResponse.fromJson(json);
}
