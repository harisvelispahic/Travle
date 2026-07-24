import '../models/tour_type_response.dart';
import '../network/base_provider.dart';

/// Reads tour types (`GET /TourTypes`). Reads require an authenticated user;
/// writes are admin-only (desktop reference CRUD).
class TourTypeProvider extends BaseProvider<TourTypeResponse> {
  TourTypeProvider() : super('TourTypes');

  @override
  TourTypeResponse fromJson(Map<String, dynamic> json) =>
      TourTypeResponse.fromJson(json);
}
