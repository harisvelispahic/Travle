import 'package:json_annotation/json_annotation.dart';

part 'review_update_request.g.dart';

/// An author's edit of their own review — rating + comment only (mirrors the
/// backend `DestinationReviewUpdateRequest` / `TourReviewUpdateRequest`, which
/// share the same shape). The target is fixed and never re-sent.
@JsonSerializable()
class ReviewUpdateRequest {
  ReviewUpdateRequest({
    required this.rating,
    this.comment,
  });

  final int rating;
  final String? comment;

  factory ReviewUpdateRequest.fromJson(Map<String, dynamic> json) =>
      _$ReviewUpdateRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ReviewUpdateRequestToJson(this);
}
