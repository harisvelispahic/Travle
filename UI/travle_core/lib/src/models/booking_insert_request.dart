import 'package:json_annotation/json_annotation.dart';

part 'booking_insert_request.g.dart';

/// A traveler's request to book a tour schedule (mirrors the backend
/// `BookingInsertRequest`). The user and the total are resolved server-side —
/// only the slot and the group size come from the client.
@JsonSerializable()
class BookingInsertRequest {
  BookingInsertRequest({
    required this.tourScheduleId,
    required this.numberOfPeople,
  });

  final int tourScheduleId;
  final int numberOfPeople;

  factory BookingInsertRequest.fromJson(Map<String, dynamic> json) =>
      _$BookingInsertRequestFromJson(json);

  Map<String, dynamic> toJson() => _$BookingInsertRequestToJson(this);
}
