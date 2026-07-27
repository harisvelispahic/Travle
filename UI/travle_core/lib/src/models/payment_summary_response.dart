import 'package:json_annotation/json_annotation.dart';

part 'payment_summary_response.g.dart';

/// Aggregate totals for the admin payments screen (mirrors the backend
/// `PaymentSummaryResponse`), computed over the same filter as the list.
/// "Captured" = payments actually charged; commission is the snapshotted 10%
/// platform fee (bookkeeping only). [netRevenue] = gross captured − refunded.
@JsonSerializable()
class PaymentSummaryResponse {
  PaymentSummaryResponse({
    required this.capturedCount,
    required this.grossRevenue,
    required this.platformCommission,
    required this.organizerShare,
    required this.totalRefunded,
    required this.refundCount,
    required this.netRevenue,
    required this.currency,
  });

  final int capturedCount;
  final double grossRevenue;
  final double platformCommission;
  final double organizerShare;
  final double totalRefunded;
  final int refundCount;
  final double netRevenue;
  final String currency;

  factory PaymentSummaryResponse.fromJson(Map<String, dynamic> json) =>
      _$PaymentSummaryResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PaymentSummaryResponseToJson(this);
}
