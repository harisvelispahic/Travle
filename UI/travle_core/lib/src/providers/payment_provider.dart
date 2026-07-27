import '../models/payment_intent_response.dart';
import '../models/payment_response.dart';
import '../models/payment_summary_response.dart';
import '../network/base_provider.dart';

/// Payments (`/Payments`). Two audiences: a traveler starts a payment for their
/// held booking ([createIntent]); an admin reads the payments list (the inherited
/// paginated `get`) and the [summary] totals. The base type is [PaymentResponse]
/// (the admin list row); the create-intent path parses its own response shape.
class PaymentProvider extends BaseProvider<PaymentResponse> {
  PaymentProvider() : super('Payments');

  @override
  PaymentResponse fromJson(Map<String, dynamic> json) =>
      PaymentResponse.fromJson(json);

  /// Traveler starts (or resumes) paying for a held booking
  /// (`POST /Payments/CreateIntent`) → the Stripe PaymentSheet client secret.
  Future<PaymentIntentResponse> createIntent(int bookingId) async {
    final json = await postAction('CreateIntent', {'bookingId': bookingId});
    return PaymentIntentResponse.fromJson(json as Map<String, dynamic>);
  }

  /// Admin revenue / commission / refund totals (`GET /Payments/summary`),
  /// over the same filter as the list.
  Future<PaymentSummaryResponse> summary({dynamic filter}) async {
    final json = await getAction('summary', filter: filter) as Map<String, dynamic>;
    return PaymentSummaryResponse.fromJson(json);
  }
}
