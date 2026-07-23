// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'region_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RegionResponse _$RegionResponseFromJson(Map<String, dynamic> json) =>
    RegionResponse(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      countryId: (json['countryId'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      countryName: json['countryName'] as String?,
      modifiedAt: json['modifiedAt'] == null
          ? null
          : DateTime.parse(json['modifiedAt'] as String),
    );

Map<String, dynamic> _$RegionResponseToJson(RegionResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'countryId': instance.countryId,
      'countryName': instance.countryName,
      'createdAt': instance.createdAt.toIso8601String(),
      'modifiedAt': instance.modifiedAt?.toIso8601String(),
    };
