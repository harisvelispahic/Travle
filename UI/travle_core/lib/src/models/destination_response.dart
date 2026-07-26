import 'package:json_annotation/json_annotation.dart';

import 'destination_image_response.dart';
import 'tag_ref.dart';

part 'destination_response.g.dart';

/// A tourist destination in the single shape every read path returns — list card,
/// detail, and edit prefill (mirrors the backend `DestinationResponse`). Reference
/// fields are flattened to names (never raw ids shown) and [status] is the enum
/// name. Only [primaryThumbnail] carries bytes (a small list-card thumbnail);
/// [images] is metadata, with full bytes fetched from the image endpoint.
@JsonSerializable()
class DestinationResponse {
  DestinationResponse({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.cityId,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.isFeatured,
    required this.averageRating,
    required this.viewCount,
    required this.submittedByUserId,
    required this.createdAt,
    this.entranceFee,
    this.categoryName,
    this.cityName,
    this.regionName,
    this.countryName,
    this.submittedByUsername,
    this.moderatedByUserId,
    this.moderatedByUsername,
    this.moderatedAt,
    this.rejectionReason,
    this.tags = const [],
    this.images = const [],
    this.primaryThumbnail,
    this.primaryThumbnailContentType,
    this.modifiedAt,
  });

  final int id;
  final String name;
  final String description;

  final int categoryId;
  final String? categoryName;

  final int cityId;
  final String? cityName;
  final String? regionName;
  final String? countryName;

  final double latitude;
  final double longitude;

  /// Optional entrance fee (KM) paid at the destination — never part of a tour's
  /// price. Null = free/unknown; the amount is an approximate "bring around X" guide.
  final double? entranceFee;

  /// Pending / Approved / Rejected — the enum name, never a raw int.
  final String status;

  final bool isFeatured;
  final double averageRating;
  final int viewCount;

  final int submittedByUserId;
  final String? submittedByUsername;

  final int? moderatedByUserId;
  final String? moderatedByUsername;
  final DateTime? moderatedAt;
  final String? rejectionReason;

  final List<TagRef> tags;
  final List<DestinationImageResponse> images;

  /// Base64 thumbnail bytes for the list card (null when there is no image).
  final String? primaryThumbnail;
  final String? primaryThumbnailContentType;

  final DateTime createdAt;
  final DateTime? modifiedAt;

  bool get isPending => status == 'Pending';
  bool get isApproved => status == 'Approved';
  bool get isRejected => status == 'Rejected';

  factory DestinationResponse.fromJson(Map<String, dynamic> json) =>
      _$DestinationResponseFromJson(json);

  Map<String, dynamic> toJson() => _$DestinationResponseToJson(this);
}
