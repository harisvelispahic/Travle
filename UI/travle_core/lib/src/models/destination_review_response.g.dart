// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'destination_review_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DestinationReviewResponse _$DestinationReviewResponseFromJson(
  Map<String, dynamic> json,
) => DestinationReviewResponse(
  id: (json['id'] as num).toInt(),
  destinationId: (json['destinationId'] as num).toInt(),
  destinationName: json['destinationName'] as String,
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

Map<String, dynamic> _$DestinationReviewResponseToJson(
  DestinationReviewResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'destinationId': instance.destinationId,
  'destinationName': instance.destinationName,
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
