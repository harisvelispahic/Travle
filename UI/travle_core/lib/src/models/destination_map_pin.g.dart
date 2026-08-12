// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'destination_map_pin.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DestinationMapPin _$DestinationMapPinFromJson(Map<String, dynamic> json) =>
    DestinationMapPin(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      averageRating: (json['averageRating'] as num).toDouble(),
      categoryName: json['categoryName'] as String?,
      primaryThumbnail: json['primaryThumbnail'] as String?,
      primaryThumbnailContentType:
          json['primaryThumbnailContentType'] as String?,
    );

Map<String, dynamic> _$DestinationMapPinToJson(DestinationMapPin instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'categoryName': instance.categoryName,
      'averageRating': instance.averageRating,
      'primaryThumbnail': instance.primaryThumbnail,
      'primaryThumbnailContentType': instance.primaryThumbnailContentType,
    };
