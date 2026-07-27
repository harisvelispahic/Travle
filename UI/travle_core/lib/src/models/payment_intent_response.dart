import 'package:json_annotation/json_annotation.dart';

part 'payment_intent_response.g.dart';

/// What the client needs to present the Stripe PaymentSheet for a booking
/// (mirrors the backend `PaymentIntentResponse`). [clientSecret] is the
/// per-intent secret the Stripe SDK confirms against; [publishableKey] is the
/// non-secret `pk_test_…` the SDK is initialised with. [amount]/[currency] are
/// the server-computed source of truth, shown for confirmation only — payment
/// success is recorded solely by the signature-verified webhook, never here.
@JsonSerializable()
class PaymentIntentResponse {
  PaymentIntentResponse({
    required this.bookingId,
    required this.paymentId,
    required this.clientSecret,
    required this.publishableKey,
    required this.amount,
    required this.currency,
  });

  final int bookingId;
  final int paymentId;
  final String clientSecret;
  final String publishableKey;
  final double amount;
  final String currency;

  factory PaymentIntentResponse.fromJson(Map<String, dynamic> json) =>
      _$PaymentIntentResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PaymentIntentResponseToJson(this);
}
