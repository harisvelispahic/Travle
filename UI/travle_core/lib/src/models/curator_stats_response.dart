import 'package:json_annotation/json_annotation.dart';

part 'curator_stats_response.g.dart';

/// The curator statistics headline payload (mirrors the backend `CuratorStatsResponse`):
/// the aggregate impact of the caller's submitted destinations — portfolio health,
/// engagement (views / favorites / ratings) and the demand they drive (bookings /
/// travelers on tours that visit them). Totals over all the curator's destinations; the
/// per-destination breakdown is fetched separately (paginated). Curators earn no money,
/// so there are no revenue figures here.
@JsonSerializable()
class CuratorStatsResponse {
  CuratorStatsResponse({
    required this.totalDestinations,
    required this.approvedDestinations,
    required this.pendingDestinations,
    required this.rejectedDestinations,
    required this.totalViews,
    required this.totalFavorites,
    required this.averageRating,
    required this.reviewCount,
    required this.totalBookings,
    required this.totalTravelers,
  });

  final int totalDestinations;
  final int approvedDestinations;
  final int pendingDestinations;
  final int rejectedDestinations;
  final int totalViews;
  final int totalFavorites;
  final double averageRating;
  final int reviewCount;

  /// Distinct bookings whose tour visits at least one of the curator's destinations.
  final int totalBookings;

  /// Travelers on those bookings (sum of party sizes).
  final int totalTravelers;

  factory CuratorStatsResponse.fromJson(Map<String, dynamic> json) =>
      _$CuratorStatsResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CuratorStatsResponseToJson(this);
}
