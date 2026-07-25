import 'dart:typed_data';

import '../models/destination_insert_request.dart';
import '../models/destination_response.dart';
import '../models/destination_update_request.dart';
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
}
