import '../models/destination_review_insert_request.dart';
import '../models/destination_review_response.dart';
import '../models/review_update_request.dart';
import '../network/base_provider.dart';
import '../network/search_result.dart';

/// Destination reviews (`/DestinationReviews`). Any authenticated user reads a
/// destination's reviews and posts/edits/removes their own; admins remove any with
/// a reason. All gating (approved target, one active review, ownership) is enforced
/// server-side.
class DestinationReviewProvider extends BaseProvider<DestinationReviewResponse> {
  DestinationReviewProvider() : super('DestinationReviews');

  @override
  DestinationReviewResponse fromJson(Map<String, dynamic> json) =>
      DestinationReviewResponse.fromJson(json);

  /// A destination's reviews (`GET /DestinationReviews?destinationId=`), paginated.
  Future<SearchResult<DestinationReviewResponse>> forDestination(
    int destinationId, {
    Map<String, dynamic>? filter,
  }) {
    final query = <String, dynamic>{...?filter, 'destinationId': destinationId};
    return get(filter: query);
  }

  /// Post a review of an approved destination (`POST /DestinationReviews`).
  Future<DestinationReviewResponse> create(
          DestinationReviewInsertRequest request) =>
      insert(request.toJson());

  /// Edit your own review (`PUT /DestinationReviews/{id}`).
  Future<DestinationReviewResponse> updateReview(
          int id, ReviewUpdateRequest request) =>
      update(id, request.toJson());

  /// Remove your own review (`DELETE /DestinationReviews/{id}`; soft).
  Future<void> removeOwn(int id) => remove(id);

  /// Admin moderation removal with a reason (`POST /DestinationReviews/{id}/Remove`).
  Future<DestinationReviewResponse> adminRemove(int id, String reason) async {
    final json = await postAction('$id/Remove', {'reason': reason});
    return fromJson(json as Map<String, dynamic>);
  }
}
