// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organizer_stats_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrganizerStatsResponse _$OrganizerStatsResponseFromJson(
  Map<String, dynamic> json,
) => OrganizerStatsResponse(
  totalBookings: (json['totalBookings'] as num).toInt(),
  pendingBookings: (json['pendingBookings'] as num).toInt(),
  confirmedBookings: (json['confirmedBookings'] as num).toInt(),
  completedBookings: (json['completedBookings'] as num).toInt(),
  cancelledBookings: (json['cancelledBookings'] as num).toInt(),
  grossRevenue: (json['grossRevenue'] as num).toDouble(),
  totalRefunded: (json['totalRefunded'] as num).toDouble(),
  platformCommission: (json['platformCommission'] as num).toDouble(),
  netEarnings: (json['netEarnings'] as num).toDouble(),
  averageRating: (json['averageRating'] as num).toDouble(),
  reviewCount: (json['reviewCount'] as num).toInt(),
  currency: json['currency'] as String,
  bookingsPerMonth: (json['bookingsPerMonth'] as List<dynamic>)
      .map((e) => MonthlyBookingPoint.fromJson(e as Map<String, dynamic>))
      .toList(),
  tours: (json['tours'] as List<dynamic>)
      .map((e) => OrganizerTourStatRow.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$OrganizerStatsResponseToJson(
  OrganizerStatsResponse instance,
) => <String, dynamic>{
  'totalBookings': instance.totalBookings,
  'pendingBookings': instance.pendingBookings,
  'confirmedBookings': instance.confirmedBookings,
  'completedBookings': instance.completedBookings,
  'cancelledBookings': instance.cancelledBookings,
  'grossRevenue': instance.grossRevenue,
  'totalRefunded': instance.totalRefunded,
  'platformCommission': instance.platformCommission,
  'netEarnings': instance.netEarnings,
  'averageRating': instance.averageRating,
  'reviewCount': instance.reviewCount,
  'currency': instance.currency,
  'bookingsPerMonth': instance.bookingsPerMonth,
  'tours': instance.tours,
};
