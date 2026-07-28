// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tour_review_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TourReviewResponse _$TourReviewResponseFromJson(Map<String, dynamic> json) =>
    TourReviewResponse(
      id: (json['id'] as num).toInt(),
      tourId: (json['tourId'] as num).toInt(),
      tourName: json['tourName'] as String,
      bookingId: (json['bookingId'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      username: json['username'] as String,
      authorName: json['authorName'] as String,
      rating: (json['rating'] as num).toInt(),
      isRemoved: json['isRemoved'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      comment: json['comment'] as String?,
      removedByUserId: (json['removedByUserId'] as num?)?.toInt(),
      removedByUsername: json['removedByUsername'] as String?,
      removalReason: json['removalReason'] as String?,
      modifiedAt: json['modifiedAt'] == null
          ? null
          : DateTime.parse(json['modifiedAt'] as String),
    );

Map<String, dynamic> _$TourReviewResponseToJson(TourReviewResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tourId': instance.tourId,
      'tourName': instance.tourName,
      'bookingId': instance.bookingId,
      'userId': instance.userId,
      'username': instance.username,
      'authorName': instance.authorName,
      'rating': instance.rating,
      'comment': instance.comment,
      'isRemoved': instance.isRemoved,
      'removedByUserId': instance.removedByUserId,
      'removedByUsername': instance.removedByUsername,
      'removalReason': instance.removalReason,
      'createdAt': instance.createdAt.toIso8601String(),
      'modifiedAt': instance.modifiedAt?.toIso8601String(),
    };
