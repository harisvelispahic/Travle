// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_review.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductReview _$ProductReviewFromJson(Map<String, dynamic> json) =>
    ProductReview(
      id: (json['id'] as num).toInt(),
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      userId: (json['userId'] as num).toInt(),
      reviewerDisplayName: json['reviewerDisplayName'] as String,
      orderId: (json['orderId'] as num?)?.toInt(),
      productId: (json['productId'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ProductReviewToJson(ProductReview instance) =>
    <String, dynamic>{
      'id': instance.id,
      'rating': instance.rating,
      'comment': instance.comment,
      'createdAt': instance.createdAt.toIso8601String(),
      'userId': instance.userId,
      'reviewerDisplayName': instance.reviewerDisplayName,
      'orderId': instance.orderId,
      'productId': instance.productId,
    };
