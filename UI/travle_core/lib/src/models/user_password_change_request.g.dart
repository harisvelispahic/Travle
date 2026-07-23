// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_password_change_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserPasswordChangeRequest _$UserPasswordChangeRequestFromJson(
  Map<String, dynamic> json,
) => UserPasswordChangeRequest(
  currentPassword: json['currentPassword'] as String,
  newPassword: json['newPassword'] as String,
  confirmNewPassword: json['confirmNewPassword'] as String,
);

Map<String, dynamic> _$UserPasswordChangeRequestToJson(
  UserPasswordChangeRequest instance,
) => <String, dynamic>{
  'currentPassword': instance.currentPassword,
  'newPassword': instance.newPassword,
  'confirmNewPassword': instance.confirmNewPassword,
};
