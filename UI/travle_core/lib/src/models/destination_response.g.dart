// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'destination_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DestinationResponse _$DestinationResponseFromJson(
  Map<String, dynamic> json,
) => DestinationResponse(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  description: json['description'] as String,
  categoryId: (json['categoryId'] as num).toInt(),
  cityId: (json['cityId'] as num).toInt(),
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  status: json['status'] as String,
  isFeatured: json['isFeatured'] as bool,
  averageRating: (json['averageRating'] as num).toDouble(),
  viewCount: (json['viewCount'] as num).toInt(),
  submittedByUserId: (json['submittedByUserId'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  entranceFee: (json['entranceFee'] as num?)?.toDouble(),
  categoryName: json['categoryName'] as String?,
  cityName: json['cityName'] as String?,
  regionName: json['regionName'] as String?,
  countryName: json['countryName'] as String?,
  submittedByUsername: json['submittedByUsername'] as String?,
  moderatedByUserId: (json['moderatedByUserId'] as num?)?.toInt(),
  moderatedByUsername: json['moderatedByUsername'] as String?,
  moderatedAt: json['moderatedAt'] == null
      ? null
      : DateTime.parse(json['moderatedAt'] as String),
  rejectionReason: json['rejectionReason'] as String?,
  tags:
      (json['tags'] as List<dynamic>?)
          ?.map((e) => TagRef.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  images:
      (json['images'] as List<dynamic>?)
          ?.map(
            (e) => DestinationImageResponse.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  primaryThumbnail: json['primaryThumbnail'] as String?,
  primaryThumbnailContentType: json['primaryThumbnailContentType'] as String?,
  modifiedAt: json['modifiedAt'] == null
      ? null
      : DateTime.parse(json['modifiedAt'] as String),
);

Map<String, dynamic> _$DestinationResponseToJson(
  DestinationResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'categoryId': instance.categoryId,
  'categoryName': instance.categoryName,
  'cityId': instance.cityId,
  'cityName': instance.cityName,
  'regionName': instance.regionName,
  'countryName': instance.countryName,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'entranceFee': instance.entranceFee,
  'status': instance.status,
  'isFeatured': instance.isFeatured,
  'averageRating': instance.averageRating,
  'viewCount': instance.viewCount,
  'submittedByUserId': instance.submittedByUserId,
  'submittedByUsername': instance.submittedByUsername,
  'moderatedByUserId': instance.moderatedByUserId,
  'moderatedByUsername': instance.moderatedByUsername,
  'moderatedAt': instance.moderatedAt?.toIso8601String(),
  'rejectionReason': instance.rejectionReason,
  'tags': instance.tags,
  'images': instance.images,
  'primaryThumbnail': instance.primaryThumbnail,
  'primaryThumbnailContentType': instance.primaryThumbnailContentType,
  'createdAt': instance.createdAt.toIso8601String(),
  'modifiedAt': instance.modifiedAt?.toIso8601String(),
};
