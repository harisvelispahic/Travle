import 'dart:typed_data';

import '../models/destination_insert_request.dart';
import '../models/destination_response.dart';
import '../models/destination_update_request.dart';
import '../models/recommendation_item.dart';
import '../network/base_provider.dart';
import '../network/search_result.dart';

/// Destinations (`/Destinations`). The plain paginated `get` is the public,
/// approved-only catalogue; [mine] is the current curator/organizer's own
/// submissions (any status). Submitting/editing/deleting are enforced server-side
/// (curator/organizer + ownership).
class DestinationProvider extends BaseProvider<DestinationResponse> {
  DestinationProvider() : super('Destinations');

  @override
  DestinationResponse fromJson(Map<String, dynamic> json) =>
      DestinationResponse.fromJson(json);

  /// The current user's own destinations (`GET /Destinations/mine`), any status.
  Future<SearchResult<DestinationResponse>> mine({dynamic filter}) async {
    final json = await getAction('mine', filter: filter) as Map<String, dynamic>;
    return SearchResult<DestinationResponse>()
      ..totalCount = json['totalCount'] as int?
      ..items = (json['items'] as List)
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
  }

  /// Admin moderation queue (`GET /Destinations/moderation`); defaults to Pending
  /// server-side, filterable by `status` (0/1/2) and `text`.
  Future<SearchResult<DestinationResponse>> moderationQueue({dynamic filter}) async {
    final json =
        await getAction('moderation', filter: filter) as Map<String, dynamic>;
    return SearchResult<DestinationResponse>()
      ..totalCount = json['totalCount'] as int?
      ..items = (json['items'] as List)
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
  }

  /// Admin: approve a pending destination (publishes it). Returns the updated row.
  Future<DestinationResponse> approve(int id) async {
    final json = await postAction('$id/Approve');
    return fromJson(json as Map<String, dynamic>);
  }

  /// Admin: reject a pending destination with a mandatory reason.
  Future<DestinationResponse> reject(int id, String reason) async {
    final json = await postAction('$id/Reject', {'reason': reason});
    return fromJson(json as Map<String, dynamic>);
  }

  /// Admin: toggle the featured flag (only an approved destination may be featured).
  Future<DestinationResponse> setFeatured(int id, bool isFeatured) async {
    final json = await postAction('$id/Featured', {'isFeatured': isFeatured});
    return fromJson(json as Map<String, dynamic>);
  }

  /// A destination's detail (`GET /Destinations/{id}`). Opening an approved
  /// destination someone else submitted logs a View server-side.
  Future<DestinationResponse> getDetail(int id) => getById(id);

  /// Submits a new destination (`POST /Destinations`). Returns the created row
  /// (Pending). Curator/Organizer only, enforced server-side.
  Future<DestinationResponse> submit(DestinationInsertRequest request) =>
      insert(request.toJson());

  /// Edits a destination (`PUT /Destinations/{id}`) — sends it back to Pending.
  Future<DestinationResponse> edit(int id, DestinationUpdateRequest request) =>
      update(id, request.toJson());

  /// Deletes a destination (`DELETE /Destinations/{id}`). Allowed only while
  /// Pending and unreferenced (the server returns a friendly conflict otherwise).
  Future<void> delete(int id) => remove(id);

  /// Full image bytes for a destination image (`GET /Destinations/{id}/images/{imageId}`).
  Future<Uint8List> imageBytes(int destinationId, int imageId) =>
      getBytes('$destinationId/images/$imageId');

  /// Item-to-item "similar destinations" (`GET /Destinations/{id}/similar`) — the
  /// recommender's second surface. Needs no user profile, so it works even for
  /// brand-new users; each item carries its own "why it's similar" reason.
  Future<List<RecommendationItem>> similar(int id) async {
    final json = await getAction('$id/similar') as List;
    return json
        .map((e) => RecommendationItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
