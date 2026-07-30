import 'package:json_annotation/json_annotation.dart';

import 'recommendation_item.dart';

part 'recommendation_response.g.dart';

/// The current user's personalized recommendations (mirrors the backend
/// `RecommendationResponse`). [isColdStart] is true when the user has too little
/// signal for content-based scoring and the list is a pure-popularity fallback,
/// which the UI labels honestly.
@JsonSerializable()
class RecommendationResponse {
  RecommendationResponse({
    required this.items,
    required this.isColdStart,
  });

  final List<RecommendationItem> items;
  final bool isColdStart;

  factory RecommendationResponse.fromJson(Map<String, dynamic> json) =>
      _$RecommendationResponseFromJson(json);

  Map<String, dynamic> toJson() => _$RecommendationResponseToJson(this);
}
