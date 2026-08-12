// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'curator_stats_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CuratorStatsResponse _$CuratorStatsResponseFromJson(
  Map<String, dynamic> json,
) => CuratorStatsResponse(
  totalDestinations: (json['totalDestinations'] as num).toInt(),
  approvedDestinations: (json['approvedDestinations'] as num).toInt(),
  pendingDestinations: (json['pendingDestinations'] as num).toInt(),
  rejectedDestinations: (json['rejectedDestinations'] as num).toInt(),
  totalViews: (json['totalViews'] as num).toInt(),
  totalFavorites: (json['totalFavorites'] as num).toInt(),
  averageRating: (json['averageRating'] as num).toDouble(),
  reviewCount: (json['reviewCount'] as num).toInt(),
  totalBookings: (json['totalBookings'] as num).toInt(),
  totalTravelers: (json['totalTravelers'] as num).toInt(),
);

Map<String, dynamic> _$CuratorStatsResponseToJson(
  CuratorStatsResponse instance,
) => <String, dynamic>{
  'totalDestinations': instance.totalDestinations,
  'approvedDestinations': instance.approvedDestinations,
  'pendingDestinations': instance.pendingDestinations,
  'rejectedDestinations': instance.rejectedDestinations,
  'totalViews': instance.totalViews,
  'totalFavorites': instance.totalFavorites,
  'averageRating': instance.averageRating,
  'reviewCount': instance.reviewCount,
  'totalBookings': instance.totalBookings,
  'totalTravelers': instance.totalTravelers,
};
