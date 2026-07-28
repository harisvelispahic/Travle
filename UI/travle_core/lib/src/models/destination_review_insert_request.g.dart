// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'destination_review_insert_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DestinationReviewInsertRequest _$DestinationReviewInsertRequestFromJson(
  Map<String, dynamic> json,
) => DestinationReviewInsertRequest(
  destinationId: (json['destinationId'] as num).toInt(),
  rating: (json['rating'] as num).toInt(),
  comment: json['comment'] as String?,
);

Map<String, dynamic> _$DestinationReviewInsertRequestToJson(
  DestinationReviewInsertRequest instance,
) => <String, dynamic>{
  'destinationId': instance.destinationId,
  'rating': instance.rating,
  'comment': instance.comment,
};
