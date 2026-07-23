import 'package:json_annotation/json_annotation.dart';

part 'user_register_request.g.dart';

/// Self-service registration payload. The server always assigns the Traveler
/// role — the client never sends a role or privileged flag.
@JsonSerializable()
class UserRegisterRequest {
  UserRegisterRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.username,
    required this.password,
    this.phoneNumber,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String username;
  final String password;
  final String? phoneNumber;

  factory UserRegisterRequest.fromJson(Map<String, dynamic> json) =>
      _$UserRegisterRequestFromJson(json);

  Map<String, dynamic> toJson() => _$UserRegisterRequestToJson(this);
}
