import 'package:json_annotation/json_annotation.dart';

part 'curator_destination_stat_row.g.dart';

/// Per-destination line of the curator statistics screen (mirrors the backend
/// `CuratorDestinationStatRow`). Engagement figures apply to any status; [bookings]
/// / [travelers] count the demand on tours that visit this destination.
/// [averageRating] is 0 when the destination has no reviews yet.
@JsonSerializable()
class CuratorDestinationStatRow {
  CuratorDestinationStatRow({
    required this.destinationName,
    required this.status,
    required this.views,
    required this.favorites,
    required this.averageRating,
    required this.reviewCount,
    required this.bookings,
    required this.travelers,
  });

  final String destinationName;

  /// Moderation status name ("Pending" / "Approved" / "Rejected").
  final String status;
  final int views;
  final int favorites;
  final double averageRating;
  final int reviewCount;
  final int bookings;
  final int travelers;

  factory CuratorDestinationStatRow.fromJson(Map<String, dynamic> json) =>
      _$CuratorDestinationStatRowFromJson(json);

  Map<String, dynamic> toJson() => _$CuratorDestinationStatRowToJson(this);
}
