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
    this.modifiedAt,
  });

  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime? modifiedAt;

  factory CountryResponse.fromJson(Map<String, dynamic> json) =>
      _$CountryResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CountryResponseToJson(this);
}
