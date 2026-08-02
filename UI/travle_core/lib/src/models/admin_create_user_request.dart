import 'package:json_annotation/json_annotation.dart';

part 'admin_create_user_request.g.dart';

/// Admin account-creation payload (mirrors the backend `AdminCreateUserRequest`).
/// Unlike self-registration, the admin sets the initial [password] and picks any
/// combination of [roleIds] (including Admin). The new user manages their own
/// personal info (photo, home city) after first sign-in, so those are omitted here.
@JsonSerializable()
class AdminCreateUserRequest {
  AdminCreateUserRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.username,
    required this.password,
    required this.roleIds,
    this.phoneNumber,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String username;
  final String password;
  final String? phoneNumber;
  final List<int> roleIds;

  factory AdminCreateUserRequest.fromJson(Map<String, dynamic> json) =>
      _$AdminCreateUserRequestFromJson(json);

  Map<String, dynamic> toJson() => _$AdminCreateUserRequestToJson(this);
}
