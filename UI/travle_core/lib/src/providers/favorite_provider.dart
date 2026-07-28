import '../models/destination_response.dart';
import '../models/favorite_toggle_response.dart';
import '../models/tour_response.dart';
import '../network/base_provider.dart';
import '../network/search_result.dart';

/// Favorites (`/Favorites`) for the current user: a single toggle over one target
/// plus the two "my favorites" lists. The user id always comes from the JWT — a
/// caller only ever touches their own favorites. Generic [fromJson] parses the
/// destinations list; the tours list is parsed explicitly.
class FavoriteProvider extends BaseProvider<DestinationResponse> {
  FavoriteProvider() : super('Favorites');

  @override
  DestinationResponse fromJson(Map<String, dynamic> json) =>
      DestinationResponse.fromJson(json);

  /// Toggle a destination in favorites (`POST /Favorites/Toggle`).
  Future<FavoriteToggleResponse> toggleDestination(int destinationId) =>
      _toggle({'destinationId': destinationId});

  /// Toggle a tour in favorites (`POST /Favorites/Toggle`).
  Future<FavoriteToggleResponse> toggleTour(int tourId) =>
      _toggle({'tourId': tourId});

  /// The current user's favorited destinations (`GET /Favorites/destinations`).
  Future<SearchResult<DestinationResponse>> destinations({dynamic filter}) async {
    final json =
        await getAction('destinations', filter: filter) as Map<String, dynamic>;
    return SearchResult<DestinationResponse>()
      ..totalCount = json['totalCount'] as int?
      ..items = (json['items'] as List)
          .map((e) => DestinationResponse.fromJson(e as Map<String, dynamic>))
          .toList();
  }

  /// The current user's favorited tours (`GET /Favorites/tours`).
  Future<SearchResult<TourResponse>> tours({dynamic filter}) async {
    final json =
        await getAction('tours', filter: filter) as Map<String, dynamic>;
    return SearchResult<TourResponse>()
      ..totalCount = json['totalCount'] as int?
      ..items = (json['items'] as List)
          .map((e) => TourResponse.fromJson(e as Map<String, dynamic>))
          .toList();
  }

  Future<FavoriteToggleResponse> _toggle(Map<String, dynamic> body) async {
    final json = await postAction('Toggle', body);
    return FavoriteToggleResponse.fromJson(json as Map<String, dynamic>);
  }
}
