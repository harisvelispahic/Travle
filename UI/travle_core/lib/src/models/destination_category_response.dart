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
    this.usageCount = 0,
    this.deleteBlockedReason,
    this.modifiedAt,
  });

  final int id;
  final String name;

  /// Short blurb shown on the onboarding category card; null when unset.
  final String? description;

  /// Small base64 PNG thumbnail for the onboarding grid / admin list.
  final String? imageThumbnail;

  /// How many other records still reference this row (0 = deletable).
  @JsonKey(defaultValue: 0)
  final int usageCount;

  /// Why this row cannot be deleted, or null when it can — rendered as the
  /// disabled Delete button's tooltip (course UI rule: unavailable actions are
  /// disabled with the reason shown).
  final String? deleteBlockedReason;

  final DateTime createdAt;
  final DateTime? modifiedAt;

  factory DestinationCategoryResponse.fromJson(Map<String, dynamic> json) =>
      _$DestinationCategoryResponseFromJson(json);

  Map<String, dynamic> toJson() => _$DestinationCategoryResponseToJson(this);
}
