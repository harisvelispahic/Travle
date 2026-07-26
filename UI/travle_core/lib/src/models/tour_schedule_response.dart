import 'package:json_annotation/json_annotation.dart';

part 'tour_schedule_response.g.dart';

/// A single date/time slot of a tour with its live seat picture (mirrors the
/// backend `TourScheduleResponse`). [freeSeats] is the derived `Capacity -
/// SeatsTaken`; the [isCancellable]/[isDeletable] flags let the organizer console
/// render slot actions as disabled-with-reason.
@JsonSerializable()
class TourScheduleResponse {
  TourScheduleResponse({
    required this.id,
    required this.tourId,
    required this.startsAt,
    required this.endsAt,
    required this.capacity,
    required this.seatsTaken,
    required this.freeSeats,
    required this.status,
    required this.isCancellable,
    required this.isDeletable,
    required this.createdAt,
    this.cancelledReason,
    this.cancelledAt,
    this.modifiedAt,
  });

  final int id;
  final int tourId;

  final DateTime startsAt;
  final DateTime endsAt;

  final int capacity;
  final int seatsTaken;
  final int freeSeats;

  /// Active / Cancelled — the enum name, never a raw int.
  final String status;
  final String? cancelledReason;
  final DateTime? cancelledAt;

  final bool isCancellable;
  final bool isDeletable;

  final DateTime createdAt;
  final DateTime? modifiedAt;

  bool get isActive => status == 'Active';
  bool get isCancelled => status == 'Cancelled';

  factory TourScheduleResponse.fromJson(Map<String, dynamic> json) =>
      _$TourScheduleResponseFromJson(json);

  Map<String, dynamic> toJson() => _$TourScheduleResponseToJson(this);
}
