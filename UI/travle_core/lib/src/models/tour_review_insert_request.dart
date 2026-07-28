import 'package:json_annotation/json_annotation.dart';

part 'tour_review_insert_request.g.dart';

/// A new tour review keyed by the reviewer's own booking (mirrors the backend
/// `TourReviewInsertRequest`). The tour is derived from the booking server-side;
/// the booking must be the caller's and Completed.
@JsonSerializable()
class TourReviewInsertRequest {
  TourReviewInsertRequest({
    required this.bookingId,
    required this.rating,
    this.comment,
  });

  final int bookingId;
  final int rating;
  final String? comment;

  factory TourReviewInsertRequest.fromJson(Map<String, dynamic> json) =>
      _$TourReviewInsertRequestFromJson(json);

  Map<String, dynamic> toJson() => _$TourReviewInsertRequestToJson(this);
}
