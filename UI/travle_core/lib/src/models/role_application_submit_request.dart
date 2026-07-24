import 'package:json_annotation/json_annotation.dart';

part 'role_application_submit_request.g.dart';

/// Payload to apply for an elevated role (mirrors the backend
/// `RoleApplicationSubmitRequest`). [document] is a base64 string (the server
/// maps it back to `byte[]`); when present, [documentContentType] must be one of
/// application/pdf, image/jpeg, image/png and the bytes are magic-byte verified
/// on the server.
@JsonSerializable()
class RoleApplicationSubmitRequest {
  RoleApplicationSubmitRequest({
    required this.roleId,
    required this.motivation,
    this.regionId,
    this.document,
    this.documentContentType,
  });

  final int roleId;
  final String motivation;
  final int? regionId;
  final String? document;
  final String? documentContentType;

  factory RoleApplicationSubmitRequest.fromJson(Map<String, dynamic> json) =>
      _$RoleApplicationSubmitRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RoleApplicationSubmitRequestToJson(this);
}
