// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'popular_destinations_report.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PopularDestinationsReport _$PopularDestinationsReportFromJson(
  Map<String, dynamic> json,
) => PopularDestinationsReport(
  rows: (json['rows'] as List<dynamic>)
      .map((e) => PopularDestinationRow.fromJson(e as Map<String, dynamic>))
      .toList(),
  fromDate: json['fromDate'] == null
      ? null
      : DateTime.parse(json['fromDate'] as String),
  toDate: json['toDate'] == null
      ? null
      : DateTime.parse(json['toDate'] as String),
  categoryName: json['categoryName'] as String?,
);

Map<String, dynamic> _$PopularDestinationsReportToJson(
  PopularDestinationsReport instance,
) => <String, dynamic>{
  'rows': instance.rows,
  'fromDate': instance.fromDate?.toIso8601String(),
  'toDate': instance.toDate?.toIso8601String(),
  'categoryName': instance.categoryName,
};
