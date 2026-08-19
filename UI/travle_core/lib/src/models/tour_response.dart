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
    this.entranceFeesPerPerson = 0,
    required this.tourTypeId,
    required this.organizerId,
    required this.isActive,
    required this.destinationCount,
    required this.upcomingScheduleCount,
    required this.createdAt,
    this.hasUnavailableDestination = false,
    this.averageRating = 0,
    this.reviewCount = 0,
    this.isFavorite = false,
    this.tourTypeName,
    this.organizerName,
    this.nextDepartureAt,
    this.timeZoneId = 'UTC',
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

  /// Sum of the visited destinations' entrance fees, per person (KM), paid on-site
  /// and never part of the Travle charge. 0 when no stop has a fee.
  final double entranceFeesPerPerson;

  /// Default group size seeded into new schedules; each slot may override it.
  final int capacity;

  final int tourTypeId;
  final String? tourTypeName;

  final int organizerId;
  final String? organizerName;

  final bool isActive;

  /// True when a stop left the approved catalogue (edited back to moderation / rejected). Such a tour is
  /// hidden from travelers; on the organizer's own list it drives a "Temporarily unavailable" badge.
  final bool hasUnavailableDestination;

  /// Average of the tour's non-removed reviews (0 when it has none). Computed on read.
  final double averageRating;

  /// Number of non-removed reviews behind [averageRating].
  final int reviewCount;

  /// Whether the current user has this tour in their favorites (heart state).
  final bool isFavorite;

  final int destinationCount;
  final int upcomingScheduleCount;
  final DateTime? nextDepartureAt;

  /// IANA time-zone id (e.g. "Europe/Sarajevo") the tour's event times display in (UTC instants on the wire).
  @JsonKey(defaultValue: 'UTC')
  final String timeZoneId;

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
