import 'package:json_annotation/json_annotation.dart';

part 'destination_category_response.g.dart';

/// A destination category (mirrors the backend `DestinationCategoryResponse`).
/// Lists carry only [imageThumbnail] — a small base64 PNG shown on the onboarding
/// cards; the full illustration is served by `GET /DestinationCategories/{id}/image`.
@JsonSerializable()
class DestinationCategoryResponse {
  DestinationCategoryResponse({
    required this.id,
    required this.name,
    this.description,
    this.imageThumbnail,
    required this.createdAt,
    this.modifiedAt,
  });

  final int id;
  final String name;

  /// Short blurb shown on the onboarding category card; null when unset.
  final String? description;

  /// Small base64 PNG thumbnail for the onboarding grid / admin list.
  final String? imageThumbnail;

  final DateTime createdAt;
  final DateTime? modifiedAt;

  factory DestinationCategoryResponse.fromJson(Map<String, dynamic> json) =>
      _$DestinationCategoryResponseFromJson(json);

  Map<String, dynamic> toJson() => _$DestinationCategoryResponseToJson(this);
}
