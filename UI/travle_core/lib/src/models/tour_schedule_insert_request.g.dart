// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tour_schedule_insert_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TourScheduleInsertRequest _$TourScheduleInsertRequestFromJson(
  Map<String, dynamic> json,
) => TourScheduleInsertRequest(
  startsAt: DateTime.parse(json['startsAt'] as String),
  capacity: (json['capacity'] as num?)?.toInt(),
);

Map<String, dynamic> _$TourScheduleInsertRequestToJson(
  TourScheduleInsertRequest instance,
) => <String, dynamic>{
  'startsAt': instance.startsAt.toIso8601String(),
  'capacity': ?instance.capacity,
};
