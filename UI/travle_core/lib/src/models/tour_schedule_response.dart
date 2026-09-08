import 'package:json_annotation/json_annotation.dart';

part 'tour_schedule_response.g.dart';

/// A single date/time slot of a tour with its live seat picture (mirrors the
/// backend `TourScheduleResponse`). [freeSeats] is the derived `Capacity -
/// SeatsTaken`; the [isBookable]/[isCancellable]/[isDeletable] flags are the
/// server's own capability verdicts, so the apps gate their actions on them
/// rather than re-deriving the rules and drifting out of step.
@JsonSerializable()
class TourScheduleResponse {
  TourScheduleResponse({
    required this.id,
    required this.tourId,
    required this.startsAt,
    required this.endsAt,
    this.timeZoneId = 'UTC',
    required this.capacity,
    required this.seatsTaken,
    required this.freeSeats,
    required this.bookingCount,
    required this.status,
    required this.bookingClosesAt,
    required this.isBookable,
    required this.isCancellable,
    required this.isDeletable,
    required this.createdAt,
    this.cancelledReason,
    this.cancelledAt,
    this.deleteBlockedReason,
    this.modifiedAt,
  });

  final int id;
  final int tourId;

  final DateTime startsAt;
  final DateTime endsAt;

  /// IANA time-zone id (e.g. "Europe/Sarajevo") [startsAt]/[endsAt] display in — those are UTC instants.
  @JsonKey(defaultValue: 'UTC')
  final String timeZoneId;

  final int capacity;
  final int seatsTaken;
  final int freeSeats;

  /// Every booking row ever made on this slot, cancelled and expired ones
  /// included — unlike [seatsTaken], which counts only bookings still holding
  /// seats. This is what blocks a hard delete.
  final int bookingCount;

  /// Active / Cancelled — the enum name, never a raw int.
  final String status;
  final String? cancelledReason;
  final DateTime? cancelledAt;

  /// When this departure stops accepting new bookings and completed payments
  /// ([startsAt] minus the tour's booking cutoff). A UTC instant, displayed in
  /// [timeZoneId] like the other event times.
  final DateTime bookingClosesAt;

  /// Whether a traveler can book this slot right now — open, before
  /// [bookingClosesAt], and with a free seat.
  final bool isBookable;

  final bool isCancellable;
  final bool isDeletable;

  /// Why [isDeletable] is false, for the console's disabled-with-reason tooltip.
  final String? deleteBlockedReason;

  final DateTime createdAt;
  final DateTime? modifiedAt;

  bool get isActive => status == 'Active';
  bool get isCancelled => status == 'Cancelled';

  factory TourScheduleResponse.fromJson(Map<String, dynamic> json) =>
      _$TourScheduleResponseFromJson(json);

  Map<String, dynamic> toJson() => _$TourScheduleResponseToJson(this);
}
