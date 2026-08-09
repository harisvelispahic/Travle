// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DashboardResponse _$DashboardResponseFromJson(Map<String, dynamic> json) =>
    DashboardResponse(
      totalUsers: (json['totalUsers'] as num).toInt(),
      activeTours: (json['activeTours'] as num).toInt(),
      pendingRoleApplications: (json['pendingRoleApplications'] as num).toInt(),
      pendingDestinations: (json['pendingDestinations'] as num).toInt(),
      monthlyNetRevenue: (json['monthlyNetRevenue'] as num).toDouble(),
      currency: json['currency'] as String,
      bookingsPerMonth: (json['bookingsPerMonth'] as List<dynamic>)
          .map((e) => MonthlyBookingPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      recentActivity: (json['recentActivity'] as List<dynamic>)
          .map((e) => DashboardActivityItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$DashboardResponseToJson(DashboardResponse instance) =>
    <String, dynamic>{
      'totalUsers': instance.totalUsers,
      'activeTours': instance.activeTours,
      'pendingRoleApplications': instance.pendingRoleApplications,
      'pendingDestinations': instance.pendingDestinations,
      'monthlyNetRevenue': instance.monthlyNetRevenue,
      'currency': instance.currency,
      'bookingsPerMonth': instance.bookingsPerMonth,
      'recentActivity': instance.recentActivity,
    };
