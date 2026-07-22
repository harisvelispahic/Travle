import 'package:json_annotation/json_annotation.dart';

part 'destination_category_response.g.dart';

/// A destination category (mirrors the backend `DestinationCategoryResponse`).
@JsonSerializable()
class DestinationCategoryResponse {
  DestinationCategoryResponse({
    required this.id,
    required this.name,
    required this.createdAt,
    this.modifiedAt,
  });

  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime? modifiedAt;

  factory DestinationCategoryResponse.fromJson(Map<String, dynamic> json) =>
      _$DestinationCategoryResponseFromJson(json);

  Map<String, dynamic> toJson() => _$DestinationCategoryResponseToJson(this);
}
