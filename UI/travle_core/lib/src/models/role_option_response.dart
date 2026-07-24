import 'package:json_annotation/json_annotation.dart';

part 'role_option_response.g.dart';

/// An elevated role the current user may apply for (mirrors the backend
/// `RoleOptionResponse`). The client resolves the target role id by name from
/// this set rather than hardcoding it.
@JsonSerializable()
class RoleOptionResponse {
  RoleOptionResponse({required this.id, required this.name});

  final int id;
  final String name;

  factory RoleOptionResponse.fromJson(Map<String, dynamic> json) =>
      _$RoleOptionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$RoleOptionResponseToJson(this);
}
