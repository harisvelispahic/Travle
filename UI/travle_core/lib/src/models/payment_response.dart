import 'package:json_annotation/json_annotation.dart';

part 'payment_response.g.dart';

/// A payment as shown on the admin payments screen (mirrors the backend
/// `PaymentResponse`). Reference fields are flattened to names (traveler, tour).
/// [status] is the enum name; [refundedAmount] is the total refunded against it.
@JsonSerializable()
class PaymentResponse {
  PaymentResponse({
    required this.id,
    required this.bookingId,
    required this.travelerName,
    required this.travelerUsername,
    required this.tourName,
    required this.amount,
    required this.currency,
    required this.platformFeePercentage,
    required this.platformFeeAmount,
    required this.status,
    required this.refundedAmount,
    required this.refundCount,
    required this.createdAt,
    this.succeededAt,
  });

  final int id;
  final int bookingId;
  final String travelerName;
  final String travelerUsername;
  final String tourName;

  final double amount;
  final String currency;

  final double platformFeePercentage;
  final double platformFeeAmount;

  /// Pending / Succeeded / Failed / Refunded / PartiallyRefunded.
  final String status;

  final double refundedAmount;
  final int refundCount;

  final DateTime? succeededAt;
  final DateTime createdAt;

  factory PaymentResponse.fromJson(Map<String, dynamic> json) =>
      _$PaymentResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PaymentResponseToJson(this);
}
