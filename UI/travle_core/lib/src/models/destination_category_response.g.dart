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
  description: json['description'] as String?,
  imageThumbnail: json['imageThumbnail'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
  deleteBlockedReason: json['deleteBlockedReason'] as String?,
  modifiedAt: json['modifiedAt'] == null
      ? null
      : DateTime.parse(json['modifiedAt'] as String),
);

Map<String, dynamic> _$DestinationCategoryResponseToJson(
  DestinationCategoryResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'imageThumbnail': instance.imageThumbnail,
  'usageCount': instance.usageCount,
  'deleteBlockedReason': instance.deleteBlockedReason,
  'createdAt': instance.createdAt.toIso8601String(),
  'modifiedAt': instance.modifiedAt?.toIso8601String(),
};
