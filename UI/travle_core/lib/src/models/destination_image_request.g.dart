// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'destination_image_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DestinationImageRequest _$DestinationImageRequestFromJson(
  Map<String, dynamic> json,
) => DestinationImageRequest(
  data: json['data'] as String,
  contentType: json['contentType'] as String,
  sortOrder: (json['sortOrder'] as num).toInt(),
);

Map<String, dynamic> _$DestinationImageRequestToJson(
  DestinationImageRequest instance,
) => <String, dynamic>{
  'data': instance.data,
  'contentType': instance.contentType,
  'sortOrder': instance.sortOrder,
};
