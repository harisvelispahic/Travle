import 'package:json_annotation/json_annotation.dart';

part 'organizer_tour_stat_row.g.dart';

/// Per-tour line of the organizer statistics screen (mirrors the backend
/// `OrganizerTourStatRow`). [averageRating] is 0 when the tour has no reviews yet.
@JsonSerializable()
class OrganizerTourStatRow {
  OrganizerTourStatRow({
    required this.tourName,
    required this.bookings,
    required this.netEarnings,
    required this.averageRating,
    required this.reviewCount,
  });

  final String tourName;
  final int bookings;
  final double netEarnings;
  final double averageRating;
  final int reviewCount;

  factory OrganizerTourStatRow.fromJson(Map<String, dynamic> json) =>
      _$OrganizerTourStatRowFromJson(json);

  Map<String, dynamic> toJson() => _$OrganizerTourStatRowToJson(this);
}
