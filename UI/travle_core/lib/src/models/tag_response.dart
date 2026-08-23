import 'package:json_annotation/json_annotation.dart';

part 'tag_response.g.dart';

/// A tag (mirrors the backend `TagResponse`).
@JsonSerializable()
class TagResponse {
  TagResponse({
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

  factory TagResponse.fromJson(Map<String, dynamic> json) =>
      _$TagResponseFromJson(json);

  Map<String, dynamic> toJson() => _$TagResponseToJson(this);
}
