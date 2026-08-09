// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monthly_booking_point.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MonthlyBookingPoint _$MonthlyBookingPointFromJson(Map<String, dynamic> json) =>
    MonthlyBookingPoint(
      year: (json['year'] as num).toInt(),
      month: (json['month'] as num).toInt(),
      count: (json['count'] as num).toInt(),
      label: json['label'] as String,
    );

Map<String, dynamic> _$MonthlyBookingPointToJson(
  MonthlyBookingPoint instance,
) => <String, dynamic>{
  'year': instance.year,
  'month': instance.month,
  'count': instance.count,
  'label': instance.label,
};
