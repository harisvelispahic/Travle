import 'package:json_annotation/json_annotation.dart';

import 'destination_image_request.dart';

part 'destination_insert_request.g.dart';

/// A curator/organizer's destination submission (mirrors the backend
/// `DestinationInsertRequest`). The submitter comes from the JWT and the status
/// always starts Pending — neither is sent here. Coordinates are entered directly
/// for now (a map picker replaces the manual fields later).
@JsonSerializable()
class DestinationInsertRequest {
  DestinationInsertRequest({
    required this.name,
    required this.description,
    required this.categoryId,
    required this.cityId,
    required this.latitude,
    required this.longitude,
    this.tagIds = const [],
    this.images = const [],
  });

  final String name;
  final String description;
  final int categoryId;
  final int cityId;
  final double latitude;
  final double longitude;
  final List<int> tagIds;
  final List<DestinationImageRequest> images;

  factory DestinationInsertRequest.fromJson(Map<String, dynamic> json) =>
      _$DestinationInsertRequestFromJson(json);

  Map<String, dynamic> toJson() => _$DestinationInsertRequestToJson(this);
}
