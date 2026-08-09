// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revenue_group_row.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RevenueGroupRow _$RevenueGroupRowFromJson(Map<String, dynamic> json) =>
    RevenueGroupRow(
      groupName: json['groupName'] as String,
      bookings: (json['bookings'] as num).toInt(),
      grossRevenue: (json['grossRevenue'] as num).toDouble(),
      refunded: (json['refunded'] as num).toDouble(),
      netRevenue: (json['netRevenue'] as num).toDouble(),
    );

Map<String, dynamic> _$RevenueGroupRowToJson(RevenueGroupRow instance) =>
    <String, dynamic>{
      'groupName': instance.groupName,
      'bookings': instance.bookings,
      'grossRevenue': instance.grossRevenue,
      'refunded': instance.refunded,
      'netRevenue': instance.netRevenue,
    };
