// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_update_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReviewUpdateRequest _$ReviewUpdateRequestFromJson(Map<String, dynamic> json) =>
    ReviewUpdateRequest(
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
    );

Map<String, dynamic> _$ReviewUpdateRequestToJson(
  ReviewUpdateRequest instance,
) => <String, dynamic>{'rating': instance.rating, 'comment': instance.comment};
