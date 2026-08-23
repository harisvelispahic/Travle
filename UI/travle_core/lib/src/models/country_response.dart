import 'package:json_annotation/json_annotation.dart';

part 'country_response.g.dart';

/// A country (mirrors the backend `CountryResponse`). Top of the
/// Country → Region → City location chain.
@JsonSerializable()
class CountryResponse {
  CountryResponse({
    required this.id,
    required this.name,
    required this.createdAt,
    this.usageCount = 0,
    this.deleteBlockedReason,
    this.modifiedAt,
  });

  final int id;
  final String name;
  /// How many other records still reference this row (0 = deletable).
  @JsonKey(defaultValue: 0)
  final int usageCount;

  /// Why this row cannot be deleted, or null when it can — rendered as the
  /// disabled Delete button's tooltip (course UI rule: unavailable actions are
  /// disabled with the reason shown).
  final String? deleteBlockedReason;

  final DateTime createdAt;
  final DateTime? modifiedAt;

  factory CountryResponse.fromJson(Map<String, dynamic> json) =>
      _$CountryResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CountryResponseToJson(this);
}
