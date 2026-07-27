import '../models/payment_intent_response.dart';
import '../network/base_provider.dart';

/// Payments (`/Payments`). Not a CRUD resource — the only client action is
/// starting a payment for a held booking; the amount and platform-fee snapshot
/// are computed server-side, and payment success is recorded solely by the
/// signature-verified webhook (never reported by the client).
class PaymentProvider extends BaseProvider<PaymentIntentResponse> {
  PaymentProvider() : super('Payments');

  @override
  PaymentIntentResponse fromJson(Map<String, dynamic> json) =>
      PaymentIntentResponse.fromJson(json);

  /// Starts (or resumes) paying for the traveler's own PaymentInProgress booking
  /// (`POST /Payments/CreateIntent`). Returns the Stripe PaymentIntent client
  /// secret for the PaymentSheet. Ownership and the hold precondition are
  /// enforced server-side.
  Future<PaymentIntentResponse> createIntent(int bookingId) async {
    final json = await postAction('CreateIntent', {'bookingId': bookingId});
    return fromJson(json as Map<String, dynamic>);
  }
}
