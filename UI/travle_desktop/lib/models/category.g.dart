// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Category _$CategoryFromJson(Map<String, dynamic> json) => Category(
  id: (json['id'] as num?)?.toInt(),
  name: json['name'] as String?,
  description: json['description'] as String?,
  parentCategoryId: (json['parentCategoryId'] as num?)?.toInt(),
  isActive: json['isActive'] as bool?,
);

Map<String, dynamic> _$CategoryToJson(Category instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'parentCategoryId': instance.parentCategoryId,
  'isActive': instance.isActive,
};
