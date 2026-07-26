import 'package:json_annotation/json_annotation.dart';

import 'tour_destination_ref.dart';
import 'tour_schedule_response.dart';

part 'tour_response.g.dart';

/// A bookable tour in the single shape every read path returns — list card,
/// "tours visiting a destination", and detail (mirrors the backend `TourResponse`).
/// Only [primaryThumbnail] carries bytes on the list path (the ordered-first
/// destination's thumbnail, reused as the cover). [destinations] and [schedules]
/// are populated on the detail read only, so list payloads stay light.
@JsonSerializable()
class TourResponse {
  TourResponse({
    required this.id,
    required this.name,
    required this.description,
    required this.durationMinutes,
    required this.pricePerPerson,
    required this.capacity,
    required this.tourTypeId,
    required this.organizerId,
    required this.isActive,
    required this.destinationCount,
    required this.upcomingScheduleCount,
    required this.createdAt,
    this.tourTypeName,
    this.organizerName,
    this.nextDepartureAt,
    this.primaryThumbnail,
    this.primaryThumbnailContentType,
    this.destinations = const [],
    this.schedules,
    this.modifiedAt,
  });

  final int id;

  final String name;
  final String description;

  final int durationMinutes;
  final double pricePerPerson;

  /// Default group size seeded into new schedules; each slot may override it.
  final int capacity;

  final int tourTypeId;
  final String? tourTypeName;

  final int organizerId;
  final String? organizerName;

  final bool isActive;

  final int destinationCount;
  final int upcomingScheduleCount;
  final DateTime? nextDepartureAt;

  /// Base64 cover thumbnail for list cards (null when no stop has an image).
  final String? primaryThumbnail;
  final String? primaryThumbnailContentType;

  /// Ordered stops — populated on the detail read only (empty in lists).
  final List<TourDestinationRef> destinations;

  /// Upcoming Active schedules with live free-seat counts — detail read only.
  final List<TourScheduleResponse>? schedules;

  final DateTime createdAt;
  final DateTime? modifiedAt;

  factory TourResponse.fromJson(Map<String, dynamic> json) =>
      _$TourResponseFromJson(json);

  Map<String, dynamic> toJson() => _$TourResponseToJson(this);
}
