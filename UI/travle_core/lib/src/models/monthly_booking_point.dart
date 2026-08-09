import 'package:json_annotation/json_annotation.dart';

part 'monthly_booking_point.g.dart';

/// One bar of a bookings-per-month chart (mirrors the backend `MonthlyBookingPoint`).
/// [label] is a ready-to-render "Mon yyyy" caption; the series carries a continuous
/// run of months with gaps filled by zero.
@JsonSerializable()
class MonthlyBookingPoint {
  MonthlyBookingPoint({
    required this.year,
    required this.month,
    required this.count,
    required this.label,
  });

  final int year;
  final int month;
  final int count;
  final String label;

  factory MonthlyBookingPoint.fromJson(Map<String, dynamic> json) =>
      _$MonthlyBookingPointFromJson(json);

  Map<String, dynamic> toJson() => _$MonthlyBookingPointToJson(this);
}
