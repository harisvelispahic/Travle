// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'destination_suggestion.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DestinationSuggestion _$DestinationSuggestionFromJson(
  Map<String, dynamic> json,
) => DestinationSuggestion(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  cityName: json['cityName'] as String?,
  categoryName: json['categoryName'] as String?,
);

Map<String, dynamic> _$DestinationSuggestionToJson(
  DestinationSuggestion instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'cityName': instance.cityName,
  'categoryName': instance.categoryName,
};
