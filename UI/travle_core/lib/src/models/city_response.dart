import 'package:json_annotation/json_annotation.dart';

part 'city_response.g.dart';

/// A city belonging to a region (mirrors the backend `CityResponse`). Bottom of
/// the Country → Region → City location chain; a user's home city points here.
@JsonSerializable()
class CityResponse {
  CityResponse({
    required this.id,
    required this.name,
    required this.regionId,
    required this.createdAt,
    this.regionName,
    this.timeZoneId = 'UTC',
    this.modifiedAt,
  });

  final int id;
  final String name;
  final int regionId;

  /// Flattened parent region name (present on detail reads).
  final String? regionName;

  /// IANA time-zone id (e.g. "Europe/Sarajevo") the city's tours display event times in.
  @JsonKey(defaultValue: 'UTC')
  final String timeZoneId;

  final DateTime createdAt;
  final DateTime? modifiedAt;

  factory CityResponse.fromJson(Map<String, dynamic> json) =>
      _$CityResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CityResponseToJson(this);
}
