import 'package:json_annotation/json_annotation.dart';

part 'user_password_change_request.g.dart';

/// A user changing their own password (mirrors the backend
/// `UserPasswordChangeRequest`). The account comes from the JWT, never the body,
/// so there is no id here; the current password is confirmed server-side.
@JsonSerializable()
class UserPasswordChangeRequest {
  UserPasswordChangeRequest({
    required this.currentPassword,
    required this.newPassword,
    required this.confirmNewPassword,
  });

  final String currentPassword;
  final String newPassword;
  final String confirmNewPassword;

  factory UserPasswordChangeRequest.fromJson(Map<String, dynamic> json) =>
      _$UserPasswordChangeRequestFromJson(json);

  Map<String, dynamic> toJson() => _$UserPasswordChangeRequestToJson(this);
}
