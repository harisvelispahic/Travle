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
    this.modifiedAt,
  });

  final int id;
  final String name;
  final int countryId;

  /// Flattened parent country name (present on detail reads).
  final String? countryName;
  final DateTime createdAt;
  final DateTime? modifiedAt;

  factory RegionResponse.fromJson(Map<String, dynamic> json) =>
      _$RegionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$RegionResponseToJson(this);
}
