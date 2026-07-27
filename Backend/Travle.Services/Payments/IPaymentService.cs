using Travle.Model.Requests;
using Travle.Model.Responses;

namespace Travle.Services.Payments
{
    /// <summary>
    /// Orchestrates payments on top of <see cref="IStripeService"/>: it owns the server-side amount and
    /// platform-fee snapshot, the double-payment guard, and the <c>Payment</c> row lifecycle. The booking
    /// itself is only ever moved by the state machine — a successful payment promotes the booking via the
    /// signature-verified webhook (Phase 6b), never from the create path here.
    /// </summary>
    public interface IPaymentService
    {
        /// <summary>
        /// Starts (or resumes) payment for the caller's own held booking: computes the amount and fee
        /// server-side, creates or reuses a Stripe PaymentIntent, records/updates the <c>Payment</c> row,
        /// and returns the client secret for the mobile PaymentSheet. Throws when the booking is not the
        /// caller's, is not in the PaymentInProgress hold, has expired, or has already been paid.
        /// </summary>
        Task<PaymentIntentResponse> CreateIntentAsync(PaymentIntentCreateRequest request, CancellationToken cancellationToken = default);

        /// <summary>
        /// Processes a raw Stripe webhook request: verifies its signature, then applies the effect exactly
        /// once. <c>payment_intent.succeeded</c> marks the <c>Payment</c> Succeeded and promotes the booking
        /// PaymentInProgress → Pending (via the state machine); <c>payment_intent.payment_failed</c> fails
        /// the payment and expires the hold (releasing seats). Idempotent — a replayed event is a no-op.
        /// This is the <b>only</b> place a payment is recorded as successful; the client never reports it.
        /// </summary>
        Task HandleWebhookAsync(string json, string signatureHeader, CancellationToken cancellationToken = default);
    }
}
