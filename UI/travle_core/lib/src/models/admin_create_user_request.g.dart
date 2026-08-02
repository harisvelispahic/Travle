// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_create_user_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdminCreateUserRequest _$AdminCreateUserRequestFromJson(
  Map<String, dynamic> json,
) => AdminCreateUserRequest(
  firstName: json['firstName'] as String,
  lastName: json['lastName'] as String,
  email: json['email'] as String,
  username: json['username'] as String,
  password: json['password'] as String,
  roleIds: (json['roleIds'] as List<dynamic>)
      .map((e) => (e as num).toInt())
      .toList(),
  phoneNumber: json['phoneNumber'] as String?,
);

Map<String, dynamic> _$AdminCreateUserRequestToJson(
  AdminCreateUserRequest instance,
) => <String, dynamic>{
  'firstName': instance.firstName,
  'lastName': instance.lastName,
  'email': instance.email,
  'username': instance.username,
  'password': instance.password,
  'phoneNumber': instance.phoneNumber,
  'roleIds': instance.roleIds,
};
