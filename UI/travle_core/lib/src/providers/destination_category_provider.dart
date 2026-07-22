import '../models/destination_category_response.dart';
import '../network/base_provider.dart';

/// Reads destination categories (`GET /DestinationCategories`). Reads require an
/// authenticated user; writes are admin-only (desktop reference CRUD).
class DestinationCategoryProvider
    extends BaseProvider<DestinationCategoryResponse> {
  DestinationCategoryProvider() : super('DestinationCategories');

  @override
  DestinationCategoryResponse fromJson(Map<String, dynamic> json) =>
      DestinationCategoryResponse.fromJson(json);
}
