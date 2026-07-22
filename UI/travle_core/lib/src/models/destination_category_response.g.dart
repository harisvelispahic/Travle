// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'destination_category_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DestinationCategoryResponse _$DestinationCategoryResponseFromJson(
  Map<String, dynamic> json,
) => DestinationCategoryResponse(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  modifiedAt: json['modifiedAt'] == null
      ? null
      : DateTime.parse(json['modifiedAt'] as String),
);

Map<String, dynamic> _$DestinationCategoryResponseToJson(
  DestinationCategoryResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'createdAt': instance.createdAt.toIso8601String(),
  'modifiedAt': instance.modifiedAt?.toIso8601String(),
};
