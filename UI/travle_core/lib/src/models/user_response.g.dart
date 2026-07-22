// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserResponse _$UserResponseFromJson(Map<String, dynamic> json) => UserResponse(
  id: (json['id'] as num).toInt(),
  firstName: json['firstName'] as String,
  lastName: json['lastName'] as String,
  email: json['email'] as String,
  username: json['username'] as String,
  roles: (json['roles'] as List<dynamic>).map((e) => e as String).toList(),
  isSuspended: json['isSuspended'] as bool,
  isOnboarded: json['isOnboarded'] as bool,
  createdAt: DateTime.parse(json['createdAt'] as String),
  onboardingPromptCount: (json['onboardingPromptCount'] as num?)?.toInt() ?? 0,
  phoneNumber: json['phoneNumber'] as String?,
  suspendedAt: json['suspendedAt'] == null
      ? null
      : DateTime.parse(json['suspendedAt'] as String),
  suspensionReason: json['suspensionReason'] as String?,
  cityId: (json['cityId'] as num?)?.toInt(),
  cityName: json['cityName'] as String?,
  profileImage: json['profileImage'] as String?,
  profileImageContentType: json['profileImageContentType'] as String?,
  modifiedAt: json['modifiedAt'] == null
      ? null
      : DateTime.parse(json['modifiedAt'] as String),
);

Map<String, dynamic> _$UserResponseToJson(UserResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'firstName': instance.firstName,
      'lastName': instance.lastName,
      'email': instance.email,
      'username': instance.username,
      'phoneNumber': instance.phoneNumber,
      'roles': instance.roles,
      'isSuspended': instance.isSuspended,
      'suspendedAt': instance.suspendedAt?.toIso8601String(),
      'suspensionReason': instance.suspensionReason,
      'cityId': instance.cityId,
      'cityName': instance.cityName,
      'isOnboarded': instance.isOnboarded,
      'onboardingPromptCount': instance.onboardingPromptCount,
      'profileImage': instance.profileImage,
      'profileImageContentType': instance.profileImageContentType,
      'createdAt': instance.createdAt.toIso8601String(),
      'modifiedAt': instance.modifiedAt?.toIso8601String(),
    };
