import 'package:json_annotation/json_annotation.dart';

part 'reset_password_request.g.dart';

/// Completes the reset flow: the emailed [code] plus the new password.
@JsonSerializable()
class ResetPasswordRequest {
  ResetPasswordRequest({
    required this.email,
    required this.code,
    required this.newPassword,
    required this.confirmNewPassword,
  });

  final String email;
  final String code;
  final String newPassword;
  final String confirmNewPassword;

  factory ResetPasswordRequest.fromJson(Map<String, dynamic> json) =>
      _$ResetPasswordRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ResetPasswordRequestToJson(this);
}
