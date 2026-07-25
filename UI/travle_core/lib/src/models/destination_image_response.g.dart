// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'destination_image_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DestinationImageResponse _$DestinationImageResponseFromJson(
  Map<String, dynamic> json,
) => DestinationImageResponse(
  id: (json['id'] as num).toInt(),
  contentType: json['contentType'] as String,
  sortOrder: (json['sortOrder'] as num).toInt(),
);

Map<String, dynamic> _$DestinationImageResponseToJson(
  DestinationImageResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'contentType': instance.contentType,
  'sortOrder': instance.sortOrder,
};
