import 'package:json_annotation/json_annotation.dart';

part 'destination_review_insert_request.g.dart';

/// A new destination review (mirrors the backend `DestinationReviewInsertRequest`).
/// The author is resolved server-side from the JWT.
@JsonSerializable()
class DestinationReviewInsertRequest {
  DestinationReviewInsertRequest({
    required this.destinationId,
    required this.rating,
    this.comment,
  });

  final int destinationId;
  final int rating;
  final String? comment;

  factory DestinationReviewInsertRequest.fromJson(Map<String, dynamic> json) =>
      _$DestinationReviewInsertRequestFromJson(json);

  Map<String, dynamic> toJson() => _$DestinationReviewInsertRequestToJson(this);
}
