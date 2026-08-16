import 'package:json_annotation/json_annotation.dart';

import 'tour_response.dart';

part 'organizer_profile_response.g.dart';

/// A public, traveler-facing view of a tour organizer (mirrors the backend
/// `OrganizerProfileResponse`), shown while deciding whether to book one of their
/// tours. Contact details are never exposed. [averageRating] is computed on read
/// from the organizer's tour reviews. Only [profileImageThumbnail] carries image
/// bytes (base64) — the full profile image never travels here.
@JsonSerializable()
class OrganizerProfileResponse {
  OrganizerProfileResponse({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.memberSince,
    required this.tourCount,
    this.cityName,
    this.profileImageThumbnail,
    this.averageRating = 0,
    this.reviewCount = 0,
    this.topTours = const [],
  });

  final int id;

  final String firstName;
  final String lastName;

  /// Optional home city name (never a raw id).
  final String? cityName;

  /// When the organizer joined Travle (their account creation time).
  final DateTime memberSince;

  /// Base64 avatar thumbnail (JPEG); the only image bytes on this payload.
  final String? profileImageThumbnail;

  /// Number of the organizer's active, publicly-visible tours.
  final int tourCount;

  /// Average across all of the organizer's tour reviews (0 when none). Computed on read.
  final double averageRating;

  /// Number of non-removed reviews (by non-suspended users) behind [averageRating].
  final int reviewCount;

  /// A few of the organizer's best-rated active tours, as a preview.
  final List<TourResponse> topTours;

  String get fullName => '$firstName $lastName';

  factory OrganizerProfileResponse.fromJson(Map<String, dynamic> json) =>
      _$OrganizerProfileResponseFromJson(json);

  Map<String, dynamic> toJson() => _$OrganizerProfileResponseToJson(this);
}
