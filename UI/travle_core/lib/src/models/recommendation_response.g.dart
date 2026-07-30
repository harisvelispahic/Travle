// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recommendation_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecommendationResponse _$RecommendationResponseFromJson(
  Map<String, dynamic> json,
) => RecommendationResponse(
  items: (json['items'] as List<dynamic>)
      .map((e) => RecommendationItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  isColdStart: json['isColdStart'] as bool,
);

Map<String, dynamic> _$RecommendationResponseToJson(
  RecommendationResponse instance,
) => <String, dynamic>{
  'items': instance.items,
  'isColdStart': instance.isColdStart,
};
