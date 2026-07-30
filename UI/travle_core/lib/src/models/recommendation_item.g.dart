// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recommendation_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecommendationItem _$RecommendationItemFromJson(Map<String, dynamic> json) =>
    RecommendationItem(
      destination: DestinationResponse.fromJson(
        json['destination'] as Map<String, dynamic>,
      ),
      score: (json['score'] as num).toDouble(),
      reason: json['reason'] as String,
    );

Map<String, dynamic> _$RecommendationItemToJson(RecommendationItem instance) =>
    <String, dynamic>{
      'destination': instance.destination,
      'score': instance.score,
      'reason': instance.reason,
    };
