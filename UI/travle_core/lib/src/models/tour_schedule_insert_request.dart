import 'package:json_annotation/json_annotation.dart';

part 'tour_schedule_insert_request.g.dart';

/// A new schedule slot for a tour (mirrors the backend `TourScheduleInsertRequest`).
/// The tour comes from the route; the organizer picks [startsAt] only and the end
/// is derived server-side from the tour's duration. [capacity] is optional and
/// defaults to the tour's capacity when omitted.
@JsonSerializable(includeIfNull: false)
class TourScheduleInsertRequest {
  TourScheduleInsertRequest({
    required this.startsAt,
    this.capacity,
  });

  final DateTime startsAt;

  /// Per-slot capacity; when null the tour's default capacity is used.
  final int? capacity;

  factory TourScheduleInsertRequest.fromJson(Map<String, dynamic> json) =>
      _$TourScheduleInsertRequestFromJson(json);

  Map<String, dynamic> toJson() => _$TourScheduleInsertRequestToJson(this);
}
