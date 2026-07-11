// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_type.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductType _$ProductTypeFromJson(Map<String, dynamic> json) => ProductType(
  id: (json['id'] as num?)?.toInt(),
  name: json['name'] as String?,
  description: json['description'] as String?,
);

Map<String, dynamic> _$ProductTypeToJson(ProductType instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
    };
