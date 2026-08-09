import 'package:json_annotation/json_annotation.dart';

import 'monthly_booking_point.dart';
import 'organizer_tour_stat_row.dart';

part 'organizer_stats_response.g.dart';

/// The organizer statistics payload (mirrors the backend `OrganizerStatsResponse`):
/// headline counts, revenue and average rating across the organizer's own tours, the
/// bookings-per-month series and a per-tour breakdown. [platformCommission] is
/// bookkeeping only — organizers are never paid out.
@JsonSerializable()
class OrganizerStatsResponse {
  OrganizerStatsResponse({
    required this.totalBookings,
    required this.pendingBookings,
    required this.confirmedBookings,
    required this.completedBookings,
    required this.cancelledBookings,
    required this.grossRevenue,
    required this.totalRefunded,
    required this.platformCommission,
    required this.netEarnings,
    required this.averageRating,
    required this.reviewCount,
    required this.currency,
    required this.bookingsPerMonth,
    required this.tours,
  });

  final int totalBookings;
  final int pendingBookings;
  final int confirmedBookings;
  final int completedBookings;
  final int cancelledBookings;
  final double grossRevenue;
  final double totalRefunded;
  final double platformCommission;
  final double netEarnings;
  final double averageRating;
  final int reviewCount;
  final String currency;
  final List<MonthlyBookingPoint> bookingsPerMonth;
  final List<OrganizerTourStatRow> tours;

  factory OrganizerStatsResponse.fromJson(Map<String, dynamic> json) =>
      _$OrganizerStatsResponseFromJson(json);

  Map<String, dynamic> toJson() => _$OrganizerStatsResponseToJson(this);
}
