import 'package:json_annotation/json_annotation.dart';

part 'tour_destination_ref.g.dart';

/// One ordered stop of a tour (mirrors the backend `TourDestinationRef`): the
/// destination's name and city, its coordinates (so stops can be mapped) and a
/// small [thumbnail]. [sortOrder] preserves the itinerary order. Full image bytes
/// still come from the destination image endpoint — only the thumbnail is here.
@JsonSerializable()
class TourDestinationRef {
  TourDestinationRef({
    required this.destinationId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.sortOrder,
    this.cityName,
    this.thumbnail,
    this.thumbnailContentType,
  });

  final int destinationId;
  final String name;
  final String? cityName;

  final double latitude;
  final double longitude;

  final int sortOrder;

  /// Base64 thumbnail bytes (null when the destination has no image).
  final String? thumbnail;
  final String? thumbnailContentType;

  factory TourDestinationRef.fromJson(Map<String, dynamic> json) =>
      _$TourDestinationRefFromJson(json);

  Map<String, dynamic> toJson() => _$TourDestinationRefToJson(this);
}
