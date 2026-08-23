namespace Travle.Services.Payments
{
    /// <summary>
    /// Thin seam over the Stripe SDK (Stripe.net). Everything that actually talks to Stripe lives behind
    /// this interface so the rest of the domain never references the SDK types directly — the create-intent
    /// orchestration, the webhook handler and (Phase 6c) the refund flow depend only on these small,
    /// Travle-shaped results. Test-mode only: the injected key is <c>sk_test_…</c>, so no real money moves.
    /// </summary>
    public interface IStripeService
    {
        /// <summary>
        /// Creates a Stripe PaymentIntent for <paramref name="amountMinorUnits"/> of
        /// <paramref name="currency"/> (immediate/automatic capture — see docs/payments-and-stripe.md for
        /// why we charge rather than auth-and-capture). <paramref name="idempotencyKey"/> makes a retried
        /// call return the same intent instead of creating a duplicate. Throws
        /// <c>PaymentException</c> on a Stripe error.
        /// </summary>
        Task<StripePaymentIntentResult> CreatePaymentIntentAsync(
            long amountMinorUnits,
            string currency,
            IReadOnlyDictionary<string, string> metadata,
            string idempotencyKey,
            CancellationToken cancellationToken = default);

        /// <summary>
        /// Retrieves an existing PaymentIntent (used to reuse a still-open intent when the traveler taps
        /// Pay again within the hold, rather than creating a second one). Throws <c>PaymentException</c>
        /// if Stripe cannot return it.
        /// </summary>
        Task<StripePaymentIntentResult> GetPaymentIntentAsync(
            string paymentIntentId,
            CancellationToken cancellationToken = default);

        /// <summary>
        /// Verifies a raw webhook request against the configured signing secret and returns the parsed,
        /// Travle-shaped event. This is the trust boundary: a request whose signature does not match the
        /// secret is rejected here (<c>PaymentException</c>, 400) and never acted on. The SDK
        /// <c>Event</c> type never leaves this seam.
        /// </summary>
        StripeWebhookEvent ConstructWebhookEvent(string json, string signatureHeader);

        /// <summary>
        /// Refunds <paramref name="amountMinorUnits"/> against a PaymentIntent (a partial refund; pass the
        /// full charged amount for a 100% refund). <paramref name="idempotencyKey"/> guards against a
        /// double refund on retry. Throws <c>PaymentException</c> on a Stripe error.
        /// </summary>
        Task<StripeRefundResult> CreateRefundAsync(
            string paymentIntentId,
            long amountMinorUnits,
            string idempotencyKey,
            CancellationToken cancellationToken = default);
    }

    /// <summary>The Travle-shaped subset of a Stripe Refund: its id (persisted on the <c>Refund</c> row) and status.</summary>
    public sealed record StripeRefundResult(string Id, string Status);

    /// <summary>The webhook event kinds Travle reacts to; everything else maps to <see cref="Ignored"/>.</summary>
    public enum StripeWebhookEventType
    {
        PaymentSucceeded,
        PaymentFailed,
        Ignored
    }

    /// <summary>
    /// A verified Stripe webhook event, reduced to what the payment service needs: the Stripe event id
    /// (for logging/idempotency), the mapped <see cref="Type"/>, and the affected PaymentIntent id and
    /// (on failure) the human-readable failure message.
    /// </summary>
    public sealed record StripeWebhookEvent(
        string Id,
        StripeWebhookEventType Type,
        string? PaymentIntentId,
        string? FailureMessage,
        long? AmountReceivedMinorUnits,
        string? Currency);

    /// <summary>
    /// The Travle-shaped subset of a Stripe PaymentIntent the app cares about. <see cref="ClientSecret"/>
    /// is what the mobile PaymentSheet needs; <see cref="Status"/> is the raw Stripe status string
    /// (<c>requires_payment_method</c>, <c>succeeded</c>, …) used for reuse decisions.
    /// </summary>
    public sealed record StripePaymentIntentResult(string Id, string ClientSecret, string Status);
}
