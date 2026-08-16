// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organizer_profile_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrganizerProfileResponse _$OrganizerProfileResponseFromJson(
  Map<String, dynamic> json,
) => OrganizerProfileResponse(
  id: (json['id'] as num).toInt(),
  firstName: json['firstName'] as String,
  lastName: json['lastName'] as String,
  memberSince: DateTime.parse(json['memberSince'] as String),
  tourCount: (json['tourCount'] as num).toInt(),
  cityName: json['cityName'] as String?,
  profileImageThumbnail: json['profileImageThumbnail'] as String?,
  averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
  reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
  topTours:
      (json['topTours'] as List<dynamic>?)
          ?.map((e) => TourResponse.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$OrganizerProfileResponseToJson(
  OrganizerProfileResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'firstName': instance.firstName,
  'lastName': instance.lastName,
  'cityName': instance.cityName,
  'memberSince': instance.memberSince.toIso8601String(),
  'profileImageThumbnail': instance.profileImageThumbnail,
  'tourCount': instance.tourCount,
  'averageRating': instance.averageRating,
  'reviewCount': instance.reviewCount,
  'topTours': instance.topTours,
};
