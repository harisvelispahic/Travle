import 'package:json_annotation/json_annotation.dart';

part 'revenue_group_row.g.dart';

/// One aggregated row of the revenue report — a single category or region (mirrors
/// the backend `RevenueGroupRow`). [netRevenue] = [grossRevenue] − [refunded].
@JsonSerializable()
class RevenueGroupRow {
  RevenueGroupRow({
    required this.groupName,
    required this.bookings,
    required this.grossRevenue,
    required this.refunded,
    required this.netRevenue,
  });

  final String groupName;
  final int bookings;
  final double grossRevenue;
  final double refunded;
  final double netRevenue;

  factory RevenueGroupRow.fromJson(Map<String, dynamic> json) =>
      _$RevenueGroupRowFromJson(json);

  Map<String, dynamic> toJson() => _$RevenueGroupRowToJson(this);
}
