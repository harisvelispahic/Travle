// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tour_insert_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TourInsertRequest _$TourInsertRequestFromJson(Map<String, dynamic> json) =>
    TourInsertRequest(
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

Map<String, dynamic> _$TourInsertRequestToJson(TourInsertRequest instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'durationMinutes': instance.durationMinutes,
      'pricePerPerson': instance.pricePerPerson,
      'capacity': instance.capacity,
      'tourTypeId': instance.tourTypeId,
      'destinationIds': instance.destinationIds,
    };
