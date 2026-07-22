import 'package:json_annotation/json_annotation.dart';

part 'tag_response.g.dart';

/// A tag (mirrors the backend `TagResponse`).
@JsonSerializable()
class TagResponse {
  TagResponse({
    required this.id,
    required this.name,
    required this.createdAt,
    this.modifiedAt,
  });

  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime? modifiedAt;

  factory TagResponse.fromJson(Map<String, dynamic> json) =>
      _$TagResponseFromJson(json);

  Map<String, dynamic> toJson() => _$TagResponseToJson(this);
}
