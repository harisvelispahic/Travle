// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_update_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserUpdateRequest _$UserUpdateRequestFromJson(Map<String, dynamic> json) =>
    UserUpdateRequest(
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      email: json['email'] as String?,
      username: json['username'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      cityId: (json['cityId'] as num?)?.toInt(),
      profileImage: json['profileImage'] as String?,
      profileImageContentType: json['profileImageContentType'] as String?,
    );

Map<String, dynamic> _$UserUpdateRequestToJson(UserUpdateRequest instance) =>
    <String, dynamic>{
      'firstName': instance.firstName,
      'lastName': instance.lastName,
      'email': instance.email,
      'username': instance.username,
      'phoneNumber': instance.phoneNumber,
      'cityId': instance.cityId,
      'profileImage': instance.profileImage,
      'profileImageContentType': instance.profileImageContentType,
    };
