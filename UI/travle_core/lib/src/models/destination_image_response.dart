import 'package:json_annotation/json_annotation.dart';

part 'destination_image_response.g.dart';

/// Metadata for one of a destination's images (mirrors the backend
/// `DestinationImageResponse`) — never the bytes. Fetch the full image from
/// `GET /Destinations/{destinationId}/images/{id}`.
@JsonSerializable()
class DestinationImageResponse {
  DestinationImageResponse({
    required this.id,
    required this.contentType,
    required this.sortOrder,
  });

  final int id;
  final String contentType;
  final int sortOrder;

  factory DestinationImageResponse.fromJson(Map<String, dynamic> json) =>
      _$DestinationImageResponseFromJson(json);

  Map<String, dynamic> toJson() => _$DestinationImageResponseToJson(this);
}
