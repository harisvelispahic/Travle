import 'package:json_annotation/json_annotation.dart';

part 'region_response.g.dart';

/// A region belonging to a country (mirrors the backend `RegionResponse`).
/// Middle of the Country → Region → City location chain.
@JsonSerializable()
class RegionResponse {
  RegionResponse({
    required this.id,
    required this.name,
    required this.countryId,
    required this.createdAt,
    this.countryName,
    this.usageCount = 0,
    this.deleteBlockedReason,
    this.modifiedAt,
  });

  final int id;
  final String name;
  final int countryId;

  /// Flattened parent country name (present on detail reads).
  final String? countryName;
  /// How many other records still reference this row (0 = deletable).
  @JsonKey(defaultValue: 0)
  final int usageCount;

  /// Why this row cannot be deleted, or null when it can — rendered as the
  /// disabled Delete button's tooltip (course UI rule: unavailable actions are
  /// disabled with the reason shown).
  final String? deleteBlockedReason;

  final DateTime createdAt;
  final DateTime? modifiedAt;

  factory RegionResponse.fromJson(Map<String, dynamic> json) =>
      _$RegionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$RegionResponseToJson(this);
}
