// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tour_update_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TourUpdateRequest _$TourUpdateRequestFromJson(Map<String, dynamic> json) =>
    TourUpdateRequest(
      name: json['name'] as String,
      description: json['description'] as String,
      durationMinutes: (json['durationMinutes'] as num).toInt(),
      pricePerPerson: (json['pricePerPerson'] as num).toDouble(),
      capacity: (json['capacity'] as num).toInt(),
      tourTypeId: (json['tourTypeId'] as num).toInt(),
      destinationIds:
          (json['destinationIds'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
    );

Map<String, dynamic> _$TourUpdateRequestToJson(TourUpdateRequest instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'durationMinutes': instance.durationMinutes,
      'pricePerPerson': instance.pricePerPerson,
      'capacity': instance.capacity,
      'tourTypeId': instance.tourTypeId,
      'destinationIds': instance.destinationIds,
    };
