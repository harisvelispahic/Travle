import 'package:json_annotation/json_annotation.dart';

part 'favorite_toggle_response.g.dart';

/// The result of a favorite toggle (mirrors the backend `FavoriteToggleResponse`).
/// [isFavorite] is the state after the toggle — the client flips the heart from
/// this rather than assuming the outcome.
@JsonSerializable()
class FavoriteToggleResponse {
  FavoriteToggleResponse({
    required this.targetType,
    required this.targetId,
    required this.isFavorite,
  });

  /// "Destination" or "Tour".
  final String targetType;
  final int targetId;

  /// True if the target is now favorited, false if it was just removed.
  final bool isFavorite;

  factory FavoriteToggleResponse.fromJson(Map<String, dynamic> json) =>
      _$FavoriteToggleResponseFromJson(json);

  Map<String, dynamic> toJson() => _$FavoriteToggleResponseToJson(this);
}
