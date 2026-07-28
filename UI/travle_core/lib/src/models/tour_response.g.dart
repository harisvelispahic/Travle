// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tour_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TourResponse _$TourResponseFromJson(Map<String, dynamic> json) => TourResponse(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  description: json['description'] as String,
  durationMinutes: (json['durationMinutes'] as num).toInt(),
  pricePerPerson: (json['pricePerPerson'] as num).toDouble(),
  capacity: (json['capacity'] as num).toInt(),
  entranceFeesPerPerson:
      (json['entranceFeesPerPerson'] as num?)?.toDouble() ?? 0,
  tourTypeId: (json['tourTypeId'] as num).toInt(),
  organizerId: (json['organizerId'] as num).toInt(),
  isActive: json['isActive'] as bool,
  destinationCount: (json['destinationCount'] as num).toInt(),
  upcomingScheduleCount: (json['upcomingScheduleCount'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
  reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
  isFavorite: json['isFavorite'] as bool? ?? false,
  tourTypeName: json['tourTypeName'] as String?,
  organizerName: json['organizerName'] as String?,
  nextDepartureAt: json['nextDepartureAt'] == null
      ? null
      : DateTime.parse(json['nextDepartureAt'] as String),
  primaryThumbnail: json['primaryThumbnail'] as String?,
  primaryThumbnailContentType: json['primaryThumbnailContentType'] as String?,
  destinations:
      (json['destinations'] as List<dynamic>?)
          ?.map((e) => TourDestinationRef.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  schedules: (json['schedules'] as List<dynamic>?)
      ?.map((e) => TourScheduleResponse.fromJson(e as Map<String, dynamic>))
      .toList(),
  modifiedAt: json['modifiedAt'] == null
      ? null
      : DateTime.parse(json['modifiedAt'] as String),
);

Map<String, dynamic> _$TourResponseToJson(TourResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'durationMinutes': instance.durationMinutes,
      'pricePerPerson': instance.pricePerPerson,
      'entranceFeesPerPerson': instance.entranceFeesPerPerson,
      'capacity': instance.capacity,
      'tourTypeId': instance.tourTypeId,
      'tourTypeName': instance.tourTypeName,
      'organizerId': instance.organizerId,
      'organizerName': instance.organizerName,
      'isActive': instance.isActive,
      'averageRating': instance.averageRating,
      'reviewCount': instance.reviewCount,
      'isFavorite': instance.isFavorite,
      'destinationCount': instance.destinationCount,
      'upcomingScheduleCount': instance.upcomingScheduleCount,
      'nextDepartureAt': instance.nextDepartureAt?.toIso8601String(),
      'primaryThumbnail': instance.primaryThumbnail,
      'primaryThumbnailContentType': instance.primaryThumbnailContentType,
      'destinations': instance.destinations,
      'schedules': instance.schedules,
      'createdAt': instance.createdAt.toIso8601String(),
      'modifiedAt': instance.modifiedAt?.toIso8601String(),
    };
