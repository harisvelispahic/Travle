import 'package:json_annotation/json_annotation.dart';

part 'product_review.g.dart';

@JsonSerializable()
class ProductReview {
  final int id;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final int userId;
  final String reviewerDisplayName;
  final int? orderId;
  final int? productId;


  ProductReview({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.userId,
    required this.reviewerDisplayName,
    this.orderId,
    this.productId
  });

  factory ProductReview.fromJson(Map<String, dynamic> json) =>
      _$ProductReviewFromJson(json);

  Map<String, dynamic> toJson() => _$ProductReviewToJson(this);
}
