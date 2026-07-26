// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'destination_update_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DestinationImageEditItem _$DestinationImageEditItemFromJson(
  Map<String, dynamic> json,
) => DestinationImageEditItem(
  id: (json['id'] as num?)?.toInt(),
  data: json['data'] as String?,
  contentType: json['contentType'] as String?,
  sortOrder: (json['sortOrder'] as num).toInt(),
);

Map<String, dynamic> _$DestinationImageEditItemToJson(
  DestinationImageEditItem instance,
) => <String, dynamic>{
  'id': instance.id,
  'data': instance.data,
  'contentType': instance.contentType,
  'sortOrder': instance.sortOrder,
};

DestinationUpdateRequest _$DestinationUpdateRequestFromJson(
  Map<String, dynamic> json,
) => DestinationUpdateRequest(
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
            (e) => DestinationImageEditItem.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

Map<String, dynamic> _$DestinationUpdateRequestToJson(
  DestinationUpdateRequest instance,
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
