import 'package:json_annotation/json_annotation.dart';

part 'destination_map_pin.g.dart';

/// A light destination marker for the mobile map screen (mirrors the backend
/// `DestinationMapPinResponse`): just enough to drop a pin and render its tap
/// mini card — id, name, coordinates, category, rating, and a small thumbnail.
/// The full detail is fetched from the details endpoint when the card is opened.
@JsonSerializable()
class DestinationMapPin {
  DestinationMapPin({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.averageRating,
    this.categoryName,
    this.primaryThumbnail,
    this.primaryThumbnailContentType,
  });

  final int id;
  final String name;

  final double latitude;
  final double longitude;

  final String? categoryName;

  final double averageRating;

  /// Base64 thumbnail bytes for the marker's mini card (null when there is no image).
  final String? primaryThumbnail;
  final String? primaryThumbnailContentType;

  factory DestinationMapPin.fromJson(Map<String, dynamic> json) =>
      _$DestinationMapPinFromJson(json);

  Map<String, dynamic> toJson() => _$DestinationMapPinToJson(this);
}
