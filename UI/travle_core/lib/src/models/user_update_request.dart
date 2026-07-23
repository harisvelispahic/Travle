import 'package:json_annotation/json_annotation.dart';

part 'user_update_request.g.dart';

/// Profile edit payload (mirrors the backend `UserUpdateRequest`). Every field is
/// optional: a partial update, so a `null` leaves that value untouched server-side
/// (Mapster ignores nulls) — editing one field never re-sends the others.
///
/// [profileImage] is a base64 string (the server maps it back to `byte[]`); when
/// present, [profileImageContentType] must be `image/jpeg` or `image/png` and the
/// bytes are magic-byte verified on the server.
@JsonSerializable()
class UserUpdateRequest {
  UserUpdateRequest({
    this.firstName,
    this.lastName,
    this.email,
    this.username,
    this.phoneNumber,
    this.cityId,
    this.profileImage,
    this.profileImageContentType,
  });

  final String? firstName;
  final String? lastName;
  final String? email;
  final String? username;
  final String? phoneNumber;
  final int? cityId;
  final String? profileImage;
  final String? profileImageContentType;

  factory UserUpdateRequest.fromJson(Map<String, dynamic> json) =>
      _$UserUpdateRequestFromJson(json);

  Map<String, dynamic> toJson() => _$UserUpdateRequestToJson(this);
}
