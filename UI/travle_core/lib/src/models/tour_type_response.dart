import 'package:json_annotation/json_annotation.dart';

part 'tour_type_response.g.dart';

/// A tour type (mirrors the backend `TourTypeResponse`). Reference data managed
/// from the desktop console; picked when creating a tour.
@JsonSerializable()
class TourTypeResponse {
  TourTypeResponse({
    required this.id,
    required this.name,
    required this.createdAt,
    this.modifiedAt,
  });

  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime? modifiedAt;

  factory TourTypeResponse.fromJson(Map<String, dynamic> json) =>
      _$TourTypeResponseFromJson(json);

  Map<String, dynamic> toJson() => _$TourTypeResponseToJson(this);
}
