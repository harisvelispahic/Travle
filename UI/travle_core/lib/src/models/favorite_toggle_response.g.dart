// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite_toggle_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FavoriteToggleResponse _$FavoriteToggleResponseFromJson(
  Map<String, dynamic> json,
) => FavoriteToggleResponse(
  targetType: json['targetType'] as String,
  targetId: (json['targetId'] as num).toInt(),
  isFavorite: json['isFavorite'] as bool,
);

Map<String, dynamic> _$FavoriteToggleResponseToJson(
  FavoriteToggleResponse instance,
) => <String, dynamic>{
  'targetType': instance.targetType,
  'targetId': instance.targetId,
  'isFavorite': instance.isFavorite,
};
