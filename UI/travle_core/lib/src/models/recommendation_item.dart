import 'package:json_annotation/json_annotation.dart';

import 'destination_response.dart';

part 'recommendation_item.g.dart';

/// One recommended destination (mirrors the backend `RecommendationItem`): a light
/// destination card, its blended [score], and a human [reason] such as
/// "Because you're interested in Nature" or "Shares a tag you like: Ottoman".
@JsonSerializable()
class RecommendationItem {
  RecommendationItem({
    required this.destination,
    required this.score,
    required this.reason,
  });

  final DestinationResponse destination;
  final double score;
  final String reason;

  factory RecommendationItem.fromJson(Map<String, dynamic> json) =>
      _$RecommendationItemFromJson(json);

  Map<String, dynamic> toJson() => _$RecommendationItemToJson(this);
}
