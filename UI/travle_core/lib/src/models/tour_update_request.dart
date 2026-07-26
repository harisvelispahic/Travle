import 'package:json_annotation/json_annotation.dart';

part 'tour_update_request.g.dart';

/// Edit of an existing tour (mirrors the backend `TourUpdateRequest`). Content
/// only — activation state is toggled through the deactivate/activate endpoints,
/// and the organizer is never reassigned. [destinationIds] is the full desired
/// itinerary (the list order is the new sort order).
@JsonSerializable()
class TourUpdateRequest {
  TourUpdateRequest({
    required this.name,
    required this.description,
    required this.durationMinutes,
    required this.pricePerPerson,
    required this.capacity,
    required this.tourTypeId,
    this.destinationIds = const [],
  });

  final String name;
  final String description;
  final int durationMinutes;
  final double pricePerPerson;
  final int capacity;
  final int tourTypeId;
  final List<int> destinationIds;

  factory TourUpdateRequest.fromJson(Map<String, dynamic> json) =>
      _$TourUpdateRequestFromJson(json);

  Map<String, dynamic> toJson() => _$TourUpdateRequestToJson(this);
}
