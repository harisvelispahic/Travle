// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_insert_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BookingInsertRequest _$BookingInsertRequestFromJson(
  Map<String, dynamic> json,
) => BookingInsertRequest(
  tourScheduleId: (json['tourScheduleId'] as num).toInt(),
  numberOfPeople: (json['numberOfPeople'] as num).toInt(),
);

Map<String, dynamic> _$BookingInsertRequestToJson(
  BookingInsertRequest instance,
) => <String, dynamic>{
  'tourScheduleId': instance.tourScheduleId,
  'numberOfPeople': instance.numberOfPeople,
};
