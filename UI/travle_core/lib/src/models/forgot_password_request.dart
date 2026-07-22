import 'package:json_annotation/json_annotation.dart';

part 'forgot_password_request.g.dart';

/// Starts the reset flow: asks the server to email a reset code to [email].
@JsonSerializable()
class ForgotPasswordRequest {
  ForgotPasswordRequest({required this.email});

  final String email;

  factory ForgotPasswordRequest.fromJson(Map<String, dynamic> json) =>
      _$ForgotPasswordRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ForgotPasswordRequestToJson(this);
}
