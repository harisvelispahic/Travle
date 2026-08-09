// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organizer_tour_stat_row.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrganizerTourStatRow _$OrganizerTourStatRowFromJson(
  Map<String, dynamic> json,
) => OrganizerTourStatRow(
  tourName: json['tourName'] as String,
  bookings: (json['bookings'] as num).toInt(),
  netEarnings: (json['netEarnings'] as num).toDouble(),
  averageRating: (json['averageRating'] as num).toDouble(),
  reviewCount: (json['reviewCount'] as num).toInt(),
);

Map<String, dynamic> _$OrganizerTourStatRowToJson(
  OrganizerTourStatRow instance,
) => <String, dynamic>{
  'tourName': instance.tourName,
  'bookings': instance.bookings,
  'netEarnings': instance.netEarnings,
  'averageRating': instance.averageRating,
  'reviewCount': instance.reviewCount,
};
