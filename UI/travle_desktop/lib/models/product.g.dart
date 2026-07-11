// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Product _$ProductFromJson(Map<String, dynamic> json) => Product(
  id: (json['id'] as num?)?.toInt(),
  name: json['name'] as String?,
  weight: (json['weight'] as num?)?.toDouble(),
  productState: json['productState'] as String?,
  price: (json['price'] as num?)?.toDouble(),
  productTypeId: (json['productTypeId'] as num?)?.toInt(),
  unitOfMeasureId: (json['unitOfMeasureId'] as num?)?.toInt(),
);

Map<String, dynamic> _$ProductToJson(Product instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'weight': instance.weight,
  'productState': instance.productState,
  'price': instance.price,
  'productTypeId': instance.productTypeId,
  'unitOfMeasureId': instance.unitOfMeasureId,
};
