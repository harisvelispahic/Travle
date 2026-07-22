// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_register_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserRegisterRequest _$UserRegisterRequestFromJson(Map<String, dynamic> json) =>
    UserRegisterRequest(
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      cityId: (json['cityId'] as num?)?.toInt(),
    );

Map<String, dynamic> _$UserRegisterRequestToJson(
  UserRegisterRequest instance,
) => <String, dynamic>{
  'firstName': instance.firstName,
  'lastName': instance.lastName,
  'email': instance.email,
  'username': instance.username,
  'password': instance.password,
  'phoneNumber': instance.phoneNumber,
  'cityId': instance.cityId,
};
