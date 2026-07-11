import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  final int? id;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? username;
  final String? role;
  final bool? isActive;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final String? phoneNumber;
  final DateTime? updatedAt;

  User({
    this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.username,
    this.role,
    this.isActive,
    this.createdAt,
    this.lastLoginAt,
    this.phoneNumber,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);
}
