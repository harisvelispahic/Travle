// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tour_schedule_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TourScheduleResponse _$TourScheduleResponseFromJson(
  Map<String, dynamic> json,
) => TourScheduleResponse(
  id: (json['id'] as num).toInt(),
  tourId: (json['tourId'] as num).toInt(),
  startsAt: DateTime.parse(json['startsAt'] as String),
  endsAt: DateTime.parse(json['endsAt'] as String),
  timeZoneId: json['timeZoneId'] as String? ?? 'UTC',
  capacity: (json['capacity'] as num).toInt(),
  seatsTaken: (json['seatsTaken'] as num).toInt(),
  freeSeats: (json['freeSeats'] as num).toInt(),
  status: json['status'] as String,
  isCancellable: json['isCancellable'] as bool,
  isDeletable: json['isDeletable'] as bool,
  createdAt: DateTime.parse(json['createdAt'] as String),
  cancelledReason: json['cancelledReason'] as String?,
  cancelledAt: json['cancelledAt'] == null
      ? null
      : DateTime.parse(json['cancelledAt'] as String),
  modifiedAt: json['modifiedAt'] == null
      ? null
      : DateTime.parse(json['modifiedAt'] as String),
);

Map<String, dynamic> _$TourScheduleResponseToJson(
  TourScheduleResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'tourId': instance.tourId,
  'startsAt': instance.startsAt.toIso8601String(),
  'endsAt': instance.endsAt.toIso8601String(),
  'timeZoneId': instance.timeZoneId,
  'capacity': instance.capacity,
  'seatsTaken': instance.seatsTaken,
  'freeSeats': instance.freeSeats,
  'status': instance.status,
  'cancelledReason': instance.cancelledReason,
  'cancelledAt': instance.cancelledAt?.toIso8601String(),
  'isCancellable': instance.isCancellable,
  'isDeletable': instance.isDeletable,
  'createdAt': instance.createdAt.toIso8601String(),
  'modifiedAt': instance.modifiedAt?.toIso8601String(),
};
