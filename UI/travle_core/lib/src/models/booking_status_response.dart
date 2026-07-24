import 'package:json_annotation/json_annotation.dart';

part 'booking_status_response.g.dart';

/// A booking status (mirrors the backend `BookingStatusResponse`). Seeded
/// reference data the booking state machine depends on — read-only via the API.
@JsonSerializable()
class BookingStatusResponse {
  BookingStatusResponse({
    required this.id,
    required this.name,
    required this.createdAt,
    this.modifiedAt,
  });

  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime? modifiedAt;

  factory BookingStatusResponse.fromJson(Map<String, dynamic> json) =>
      _$BookingStatusResponseFromJson(json);

  Map<String, dynamic> toJson() => _$BookingStatusResponseToJson(this);
}
