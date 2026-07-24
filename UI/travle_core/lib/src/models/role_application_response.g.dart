// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'role_application_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RoleApplicationResponse _$RoleApplicationResponseFromJson(
  Map<String, dynamic> json,
) => RoleApplicationResponse(
  id: (json['id'] as num).toInt(),
  userId: (json['userId'] as num).toInt(),
  roleId: (json['roleId'] as num).toInt(),
  motivation: json['motivation'] as String,
  hasDocument: json['hasDocument'] as bool,
  status: json['status'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  username: json['username'] as String?,
  applicantName: json['applicantName'] as String?,
  roleName: json['roleName'] as String?,
  regionId: (json['regionId'] as num?)?.toInt(),
  regionName: json['regionName'] as String?,
  documentContentType: json['documentContentType'] as String?,
  decidedByUserId: (json['decidedByUserId'] as num?)?.toInt(),
  decidedByUsername: json['decidedByUsername'] as String?,
  decidedAt: json['decidedAt'] == null
      ? null
      : DateTime.parse(json['decidedAt'] as String),
  rejectionReason: json['rejectionReason'] as String?,
  modifiedAt: json['modifiedAt'] == null
      ? null
      : DateTime.parse(json['modifiedAt'] as String),
);

Map<String, dynamic> _$RoleApplicationResponseToJson(
  RoleApplicationResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'username': instance.username,
  'applicantName': instance.applicantName,
  'roleId': instance.roleId,
  'roleName': instance.roleName,
  'motivation': instance.motivation,
  'regionId': instance.regionId,
  'regionName': instance.regionName,
  'hasDocument': instance.hasDocument,
  'documentContentType': instance.documentContentType,
  'status': instance.status,
  'decidedByUserId': instance.decidedByUserId,
  'decidedByUsername': instance.decidedByUsername,
  'decidedAt': instance.decidedAt?.toIso8601String(),
  'rejectionReason': instance.rejectionReason,
  'createdAt': instance.createdAt.toIso8601String(),
  'modifiedAt': instance.modifiedAt?.toIso8601String(),
};
