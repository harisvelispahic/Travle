// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'popular_destination_row.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PopularDestinationRow _$PopularDestinationRowFromJson(
  Map<String, dynamic> json,
) => PopularDestinationRow(
  rank: (json['rank'] as num).toInt(),
  destinationName: json['destinationName'] as String,
  categoryName: json['categoryName'] as String,
  regionName: json['regionName'] as String,
  bookings: (json['bookings'] as num).toInt(),
  travelers: (json['travelers'] as num).toInt(),
  views: (json['views'] as num).toInt(),
  favorites: (json['favorites'] as num).toInt(),
);

Map<String, dynamic> _$PopularDestinationRowToJson(
  PopularDestinationRow instance,
) => <String, dynamic>{
  'rank': instance.rank,
  'destinationName': instance.destinationName,
  'categoryName': instance.categoryName,
  'regionName': instance.regionName,
  'bookings': instance.bookings,
  'travelers': instance.travelers,
  'views': instance.views,
  'favorites': instance.favorites,
};
