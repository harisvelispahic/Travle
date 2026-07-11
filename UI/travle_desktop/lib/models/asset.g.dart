// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Asset _$AssetFromJson(Map<String, dynamic> json) => Asset(
  id: (json['id'] as num?)?.toInt(),
  fileName: json['fileName'] as String?,
  contentType: json['contentType'] as String?,
  base64Content: json['base64Content'] as String?,
  productId: (json['productId'] as num?)?.toInt(),
  unitOfMeasureId: (json['unitOfMeasureId'] as num?)?.toInt(),
);

Map<String, dynamic> _$AssetToJson(Asset instance) => <String, dynamic>{
  'id': instance.id,
  'fileName': instance.fileName,
  'contentType': instance.contentType,
  'base64Content': instance.base64Content,
  'productId': instance.productId,
  'unitOfMeasureId': instance.unitOfMeasureId,
};
