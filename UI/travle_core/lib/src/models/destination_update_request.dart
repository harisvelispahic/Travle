import 'package:json_annotation/json_annotation.dart';

part 'destination_update_request.g.dart';

/// One entry in a destination edit's desired image set (mirrors the backend
/// `DestinationImageEditItem`). An item with an [id] keeps an existing image (only
/// its [sortOrder] may change); an item with [data] adds a new image. Existing
/// images whose id is absent from the list are deleted.
@JsonSerializable()
class DestinationImageEditItem {
  DestinationImageEditItem({
    this.id,
    this.data,
    this.contentType,
    required this.sortOrder,
  });

  final int? id;
  final String? data;
  final String? contentType;
  final int sortOrder;

  factory DestinationImageEditItem.fromJson(Map<String, dynamic> json) =>
      _$DestinationImageEditItemFromJson(json);

  Map<String, dynamic> toJson() => _$DestinationImageEditItemToJson(this);
}

/// Edit of an existing destination (mirrors the backend `DestinationUpdateRequest`).
/// Any edit sends the destination back to Pending for re-moderation. [images] is
/// the full desired set (keep / add / remove / reorder at once); [tagIds] is the
/// full desired tag set.
@JsonSerializable()
class DestinationUpdateRequest {
  DestinationUpdateRequest({
    required this.name,
    required this.description,
    required this.categoryId,
    required this.cityId,
    required this.latitude,
    required this.longitude,
    this.entranceFee,
    this.tagIds = const [],
    this.images = const [],
  });

  final String name;
  final String description;
  final int categoryId;
  final int cityId;
  final double latitude;
  final double longitude;

  /// Optional entrance fee (KM) paid at the destination; null = free/unknown.
  final double? entranceFee;
  final List<int> tagIds;
  final List<DestinationImageEditItem> images;

  factory DestinationUpdateRequest.fromJson(Map<String, dynamic> json) =>
      _$DestinationUpdateRequestFromJson(json);

  Map<String, dynamic> toJson() => _$DestinationUpdateRequestToJson(this);
}
