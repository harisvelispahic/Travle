import 'package:json_annotation/json_annotation.dart';

part 'tour_insert_request.g.dart';

/// An organizer's new tour (mirrors the backend `TourInsertRequest`). The
/// organizer comes from the JWT and is never sent. [destinationIds] is the ordered
/// itinerary — the list order becomes each stop's sort order — and every id must
/// reference an approved destination (verified server-side).
@JsonSerializable()
class TourInsertRequest {
  TourInsertRequest({
    required this.name,
    required this.description,
    required this.durationMinutes,
    required this.pricePerPerson,
    required this.capacity,
    required this.tourTypeId,
    this.bookingCutoffMinutes,
    this.destinationIds = const [],
  });

  final String name;
  final String description;
  final int durationMinutes;
  final double pricePerPerson;
  final int capacity;
  final int tourTypeId;

  /// Minutes before a departure that bookings and payments close for this tour.
  /// Null uses the platform default; 0 keeps a departure bookable until it starts.
  final int? bookingCutoffMinutes;

  final List<int> destinationIds;

  factory TourInsertRequest.fromJson(Map<String, dynamic> json) =>
      _$TourInsertRequestFromJson(json);

  Map<String, dynamic> toJson() => _$TourInsertRequestToJson(this);
}
