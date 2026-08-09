import 'package:json_annotation/json_annotation.dart';

part 'dashboard_activity_item.g.dart';

/// One row of the admin dashboard's recent-activity feed (mirrors the backend
/// `DashboardActivityItem`). [kind] is a stable discriminator ("Booking",
/// "RoleApplication", "Destination") the UI maps to an icon.
@JsonSerializable()
class DashboardActivityItem {
  DashboardActivityItem({
    required this.kind,
    required this.title,
    required this.description,
    required this.timestamp,
  });

  final String kind;
  final String title;
  final String description;
  final DateTime timestamp;

  factory DashboardActivityItem.fromJson(Map<String, dynamic> json) =>
      _$DashboardActivityItemFromJson(json);

  Map<String, dynamic> toJson() => _$DashboardActivityItemToJson(this);
}
