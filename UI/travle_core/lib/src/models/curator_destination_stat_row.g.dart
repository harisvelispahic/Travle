// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'curator_destination_stat_row.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CuratorDestinationStatRow _$CuratorDestinationStatRowFromJson(
  Map<String, dynamic> json,
) => CuratorDestinationStatRow(
  destinationName: json['destinationName'] as String,
  status: json['status'] as String,
  views: (json['views'] as num).toInt(),
  favorites: (json['favorites'] as num).toInt(),
  averageRating: (json['averageRating'] as num).toDouble(),
  reviewCount: (json['reviewCount'] as num).toInt(),
  bookings: (json['bookings'] as num).toInt(),
  travelers: (json['travelers'] as num).toInt(),
);

Map<String, dynamic> _$CuratorDestinationStatRowToJson(
  CuratorDestinationStatRow instance,
) => <String, dynamic>{
  'destinationName': instance.destinationName,
  'status': instance.status,
  'views': instance.views,
  'favorites': instance.favorites,
  'averageRating': instance.averageRating,
  'reviewCount': instance.reviewCount,
  'bookings': instance.bookings,
  'travelers': instance.travelers,
};
