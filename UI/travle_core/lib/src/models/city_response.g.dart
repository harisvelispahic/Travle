// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'city_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CityResponse _$CityResponseFromJson(Map<String, dynamic> json) => CityResponse(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  regionId: (json['regionId'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  regionName: json['regionName'] as String?,
  modifiedAt: json['modifiedAt'] == null
      ? null
      : DateTime.parse(json['modifiedAt'] as String),
);

Map<String, dynamic> _$CityResponseToJson(CityResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'regionId': instance.regionId,
      'regionName': instance.regionName,
      'createdAt': instance.createdAt.toIso8601String(),
      'modifiedAt': instance.modifiedAt?.toIso8601String(),
    };
