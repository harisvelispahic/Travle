// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_activity_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DashboardActivityItem _$DashboardActivityItemFromJson(
  Map<String, dynamic> json,
) => DashboardActivityItem(
  kind: json['kind'] as String,
  title: json['title'] as String,
  description: json['description'] as String,
  timestamp: DateTime.parse(json['timestamp'] as String),
);

Map<String, dynamic> _$DashboardActivityItemToJson(
  DashboardActivityItem instance,
) => <String, dynamic>{
  'kind': instance.kind,
  'title': instance.title,
  'description': instance.description,
  'timestamp': instance.timestamp.toIso8601String(),
};
