// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tour_review_insert_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TourReviewInsertRequest _$TourReviewInsertRequestFromJson(
  Map<String, dynamic> json,
) => TourReviewInsertRequest(
  bookingId: (json['bookingId'] as num).toInt(),
  rating: (json['rating'] as num).toInt(),
  comment: json['comment'] as String?,
);

Map<String, dynamic> _$TourReviewInsertRequestToJson(
  TourReviewInsertRequest instance,
) => <String, dynamic>{
  'bookingId': instance.bookingId,
  'rating': instance.rating,
  'comment': instance.comment,
};
