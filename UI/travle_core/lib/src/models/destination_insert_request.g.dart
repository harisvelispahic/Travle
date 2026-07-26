// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'destination_insert_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DestinationInsertRequest _$DestinationInsertRequestFromJson(
  Map<String, dynamic> json,
) => DestinationInsertRequest(
  name: json['name'] as String,
  description: json['description'] as String,
  categoryId: (json['categoryId'] as num).toInt(),
  cityId: (json['cityId'] as num).toInt(),
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  entranceFee: (json['entranceFee'] as num?)?.toDouble(),
  tagIds:
      (json['tagIds'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  images:
      (json['images'] as List<dynamic>?)
          ?.map(
            (e) => DestinationImageRequest.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

Map<String, dynamic> _$DestinationInsertRequestToJson(
  DestinationInsertRequest instance,
) => <String, dynamic>{
  'name': instance.name,
  'description': instance.description,
  'categoryId': instance.categoryId,
  'cityId': instance.cityId,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'entranceFee': instance.entranceFee,
  'tagIds': instance.tagIds,
  'images': instance.images,
};
