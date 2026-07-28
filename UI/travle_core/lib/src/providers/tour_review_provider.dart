import '../models/review_update_request.dart';
import '../models/tour_review_insert_request.dart';
import '../models/tour_review_response.dart';
import '../network/base_provider.dart';
import '../network/search_result.dart';

/// Tour reviews (`/TourReviews`). Any authenticated user reads a tour's reviews; a
/// traveler posts one for their own Completed booking and edits it; an organizer
/// reads the reviews across their own tours; admins remove any with a reason.
class TourReviewProvider extends BaseProvider<TourReviewResponse> {
  TourReviewProvider() : super('TourReviews');

  @override
  TourReviewResponse fromJson(Map<String, dynamic> json) =>
      TourReviewResponse.fromJson(json);

  /// A tour's reviews (`GET /TourReviews?tourId=`), paginated.
  Future<SearchResult<TourReviewResponse>> forTour(
    int tourId, {
    Map<String, dynamic>? filter,
  }) {
    final query = <String, dynamic>{...?filter, 'tourId': tourId};
    return get(filter: query);
  }

  /// Reviews across the current organizer's own tours (`GET /TourReviews/my-tours`).
  Future<SearchResult<TourReviewResponse>> forMyTours({dynamic filter}) async {
    final json =
        await getAction('my-tours', filter: filter) as Map<String, dynamic>;
    return _pageOf(json);
  }

  /// Post a review for your own Completed booking (`POST /TourReviews`).
  Future<TourReviewResponse> create(TourReviewInsertRequest request) =>
      insert(request.toJson());

  /// Edit your own review (`PUT /TourReviews/{id}`).
  Future<TourReviewResponse> updateReview(int id, ReviewUpdateRequest request) =>
      update(id, request.toJson());

  /// Remove your own review (`DELETE /TourReviews/{id}`; soft — you may review the booking again after).
  Future<void> removeOwn(int id) => remove(id);

  /// Admin moderation removal with a reason (`POST /TourReviews/{id}/Remove`).
  Future<TourReviewResponse> adminRemove(int id, String reason) async {
    final json = await postAction('$id/Remove', {'reason': reason});
    return fromJson(json as Map<String, dynamic>);
  }

  SearchResult<TourReviewResponse> _pageOf(Map<String, dynamic> json) =>
      SearchResult<TourReviewResponse>()
        ..totalCount = json['totalCount'] as int?
        ..items = (json['items'] as List)
            .map((e) => fromJson(e as Map<String, dynamic>))
            .toList();
}
