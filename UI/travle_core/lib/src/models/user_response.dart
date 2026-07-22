import 'package:json_annotation/json_annotation.dart';

part 'user_response.g.dart';

/// Public user projection (mirrors the backend `UserResponse`). [profileImage]
/// is a base64 string (from the server's `byte[]`), populated only on
/// detail/self reads — list endpoints leave it null.
@JsonSerializable()
class UserResponse {
  UserResponse({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.username,
    required this.roles,
    required this.isSuspended,
    required this.isOnboarded,
    required this.createdAt,
    this.onboardingPromptCount = 0,
    this.phoneNumber,
    this.suspendedAt,
    this.suspensionReason,
    this.cityId,
    this.cityName,
    this.profileImage,
    this.profileImageContentType,
    this.modifiedAt,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String username;
  final String? phoneNumber;
  final List<String> roles;
  final bool isSuspended;
  final DateTime? suspendedAt;
  final String? suspensionReason;
  final int? cityId;
  final String? cityName;
  final bool isOnboarded;
  @JsonKey(defaultValue: 0)
  final int onboardingPromptCount;
  final String? profileImage;
  final String? profileImageContentType;
  final DateTime createdAt;
  final DateTime? modifiedAt;

  String get fullName => '$firstName $lastName';

  factory UserResponse.fromJson(Map<String, dynamic> json) =>
      _$UserResponseFromJson(json);

  Map<String, dynamic> toJson() => _$UserResponseToJson(this);
}
