import 'package:json_annotation/json_annotation.dart';

import 'dashboard_activity_item.dart';
import 'monthly_booking_point.dart';

part 'dashboard_response.g.dart';

/// The admin dashboard payload (mirrors the backend `DashboardResponse`): headline
/// metric tiles, the bookings-per-month chart series and the recent-activity feed.
/// Money is in [currency] (displayed as "KM").
@JsonSerializable()
class DashboardResponse {
  DashboardResponse({
    required this.totalUsers,
    required this.newUsersThisMonth,
    required this.totalBookings,
    required this.activeTours,
    required this.pendingRoleApplications,
    required this.pendingDestinations,
    required this.monthlyNetRevenue,
    required this.currency,
    required this.bookingsPerMonth,
    required this.recentActivity,
  });

  final int totalUsers;
  final int newUsersThisMonth;
  final int totalBookings;
  final int activeTours;
  final int pendingRoleApplications;
  final int pendingDestinations;
  final double monthlyNetRevenue;
  final String currency;
  final List<MonthlyBookingPoint> bookingsPerMonth;
  final List<DashboardActivityItem> recentActivity;

  factory DashboardResponse.fromJson(Map<String, dynamic> json) =>
      _$DashboardResponseFromJson(json);

  Map<String, dynamic> toJson() => _$DashboardResponseToJson(this);
}
