import '../models/recommendation_response.dart';
import '../network/base_provider.dart';

/// Recommendations (`/Recommendations`) for the current user. The user id comes
/// from the JWT and every interaction is recorded server-side, so there is nothing
/// to post — a single read returns the explained top-N (or a labeled popularity
/// list for cold-start users). "Similar destinations" lives on [DestinationProvider].
class RecommendationProvider extends BaseProvider<RecommendationResponse> {
  RecommendationProvider() : super('Recommendations');

  @override
  RecommendationResponse fromJson(Map<String, dynamic> json) =>
      RecommendationResponse.fromJson(json);

  /// The current user's top-N recommendations with reasons (`GET /Recommendations`).
  Future<RecommendationResponse> getForCurrentUser() async {
    final json = await getAction(null) as Map<String, dynamic>;
    return RecommendationResponse.fromJson(json);
  }
}
