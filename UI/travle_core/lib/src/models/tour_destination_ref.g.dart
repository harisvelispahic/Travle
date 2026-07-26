// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tour_destination_ref.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TourDestinationRef _$TourDestinationRefFromJson(Map<String, dynamic> json) =>
    TourDestinationRef(
      destinationId: (json['destinationId'] as num).toInt(),
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      sortOrder: (json['sortOrder'] as num).toInt(),
      cityName: json['cityName'] as String?,
      thumbnail: json['thumbnail'] as String?,
      thumbnailContentType: json['thumbnailContentType'] as String?,
    );

Map<String, dynamic> _$TourDestinationRefToJson(TourDestinationRef instance) =>
    <String, dynamic>{
      'destinationId': instance.destinationId,
      'name': instance.name,
      'cityName': instance.cityName,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'sortOrder': instance.sortOrder,
      'thumbnail': instance.thumbnail,
      'thumbnailContentType': instance.thumbnailContentType,
    };
