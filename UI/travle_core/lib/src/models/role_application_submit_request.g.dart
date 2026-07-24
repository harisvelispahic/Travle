// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'role_application_submit_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RoleApplicationSubmitRequest _$RoleApplicationSubmitRequestFromJson(
  Map<String, dynamic> json,
) => RoleApplicationSubmitRequest(
  roleId: (json['roleId'] as num).toInt(),
  motivation: json['motivation'] as String,
  regionId: (json['regionId'] as num?)?.toInt(),
  document: json['document'] as String?,
  documentContentType: json['documentContentType'] as String?,
);

Map<String, dynamic> _$RoleApplicationSubmitRequestToJson(
  RoleApplicationSubmitRequest instance,
) => <String, dynamic>{
  'roleId': instance.roleId,
  'motivation': instance.motivation,
  'regionId': instance.regionId,
  'document': instance.document,
  'documentContentType': instance.documentContentType,
};
