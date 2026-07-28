import 'package:json_annotation/json_annotation.dart';

part 'tour_review_response.g.dart';

/// A rating + comment on a tour, gated to the reviewer's own Completed booking
/// (mirrors the backend `TourReviewResponse`). Tour and user references are
/// flattened to names. Removed reviews only reach admins.
@JsonSerializable()
class TourReviewResponse {
  TourReviewResponse({
    required this.id,
    required this.tourId,
    required this.tourName,
    required this.bookingId,
    required this.userId,
    required this.username,
    required this.authorName,
    required this.rating,
    required this.isRemoved,
    required this.createdAt,
    this.comment,
    this.removedByUserId,
    this.removedByUsername,
    this.removalReason,
    this.modifiedAt,
  });

  final int id;

  final int tourId;
  final String tourName;

  final int bookingId;

  final int userId;
  final String username;
  final String authorName;

  final int rating;
  final String? comment;

  final bool isRemoved;
  final int? removedByUserId;
  final String? removedByUsername;
  final String? removalReason;

  final DateTime createdAt;
  final DateTime? modifiedAt;

  factory TourReviewResponse.fromJson(Map<String, dynamic> json) =>
      _$TourReviewResponseFromJson(json);

  Map<String, dynamic> toJson() => _$TourReviewResponseToJson(this);
}
