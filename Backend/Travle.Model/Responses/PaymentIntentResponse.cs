namespace Travle.Model.Responses
{
    /// <summary>
    /// What the client needs to present the Stripe PaymentSheet for a booking. <see cref="ClientSecret"/>
    /// is the per-intent secret the mobile SDK confirms against; <see cref="PublishableKey"/> is the
    /// non-secret <c>pk_test_…</c> (the app also has it via <c>--dart-define</c>, echoed here for
    /// convenience). The amounts are the server-computed source of truth, shown for confirmation only —
    /// success is recorded solely by the signature-verified webhook, never by the client.
    /// </summary>
    public class PaymentIntentResponse
    {
        public int BookingId { get; set; }

        /// <summary>Our Payment row id (the Stripe intent id is never exposed to the client).</summary>
        public int PaymentId { get; set; }

        public string ClientSecret { get; set; } = string.Empty;
        public string PublishableKey { get; set; } = string.Empty;

        /// <summary>Charged amount in major units (KM), for display; e.g. 25.00.</summary>
        public decimal Amount { get; set; }
        public string Currency { get; set; } = "bam";
    }
}
