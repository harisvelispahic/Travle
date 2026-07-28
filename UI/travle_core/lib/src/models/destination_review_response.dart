import 'package:json_annotation/json_annotation.dart';

part 'destination_review_response.g.dart';

/// A rating + comment left on a destination (mirrors the backend
/// `DestinationReviewResponse`). The destination and both user references are
/// flattened to names — never raw ids shown. Removed reviews only reach admins.
@JsonSerializable()
class DestinationReviewResponse {
  DestinationReviewResponse({
    required this.id,
    required this.destinationId,
    required this.destinationName,
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

  final int destinationId;
  final String destinationName;

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

  factory DestinationReviewResponse.fromJson(Map<String, dynamic> json) =>
      _$DestinationReviewResponseFromJson(json);

  Map<String, dynamic> toJson() => _$DestinationReviewResponseToJson(this);
}
