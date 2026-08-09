// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revenue_report.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RevenueReport _$RevenueReportFromJson(Map<String, dynamic> json) =>
    RevenueReport(
      byCategory: (json['byCategory'] as List<dynamic>)
          .map((e) => RevenueGroupRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      byRegion: (json['byRegion'] as List<dynamic>)
          .map((e) => RevenueGroupRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalGross: (json['totalGross'] as num).toDouble(),
      totalRefunded: (json['totalRefunded'] as num).toDouble(),
      totalNet: (json['totalNet'] as num).toDouble(),
      currency: json['currency'] as String,
      fromDate: json['fromDate'] == null
          ? null
          : DateTime.parse(json['fromDate'] as String),
      toDate: json['toDate'] == null
          ? null
          : DateTime.parse(json['toDate'] as String),
    );

Map<String, dynamic> _$RevenueReportToJson(RevenueReport instance) =>
    <String, dynamic>{
      'byCategory': instance.byCategory,
      'byRegion': instance.byRegion,
      'totalGross': instance.totalGross,
      'totalRefunded': instance.totalRefunded,
      'totalNet': instance.totalNet,
      'currency': instance.currency,
      'fromDate': instance.fromDate?.toIso8601String(),
      'toDate': instance.toDate?.toIso8601String(),
    };
