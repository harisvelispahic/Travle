import 'package:json_annotation/json_annotation.dart';

part 'destination_image_request.g.dart';

/// A new image attached to a destination on submit (mirrors the backend
/// `DestinationImageRequest`). [data] is base64 bytes (the server maps it back to
/// `byte[]`, verifies the magic bytes against [contentType], and generates the
/// thumbnail — the client never supplies one).
@JsonSerializable()
class DestinationImageRequest {
  DestinationImageRequest({
    required this.data,
    required this.contentType,
    required this.sortOrder,
  });

  final String data;
  final String contentType;
  final int sortOrder;

  factory DestinationImageRequest.fromJson(Map<String, dynamic> json) =>
      _$DestinationImageRequestFromJson(json);

  Map<String, dynamic> toJson() => _$DestinationImageRequestToJson(this);
}
