using System.ComponentModel.DataAnnotations;

namespace Travle.Services.Payments
{
    /// <summary>
    /// Typed configuration for the payment subsystem, bound once from the <c>Payments</c> section (fed by
    /// the <c>STRIPE_*</c> / <c>PLATFORM_FEE_PERCENTAGE</c> environment variables via docker-compose, or the
    /// <c>Payments__*</c> keys in the repo-root <c>.env</c> for local runs). Secrets never live in
    /// appsettings.json (course §3.3). The Stripe keys are the <b>test-mode</b> keys — Travle never runs in
    /// live mode, so no company/KYC is ever involved (see docs/payments-and-stripe.md).
    /// </summary>
    public sealed class PaymentOptions
    {
        public const string SectionName = "Payments";

        /// <summary>Stripe secret key (<c>sk_test_…</c>). Server-side only — never sent to a client.</summary>
        [Required]
        public string StripeSecretKey { get; set; } = default!;

        /// <summary>
        /// Signing secret (<c>whsec_…</c>) for the Stripe webhook endpoint, from the Stripe CLI
        /// (<c>stripe listen</c>) locally or the dashboard endpoint in a hosted setup. Every webhook
        /// request's signature is verified against this before it is trusted. Required for Phase 6b; the
        /// data-annotation stays lenient here because the create-intent path (6a) does not need it.
        /// </summary>
        public string StripeWebhookSecret { get; set; } = string.Empty;

        /// <summary>
        /// The publishable key (<c>pk_test_…</c>). The mobile app receives its own copy via
        /// <c>--dart-define</c>; this optional copy lets the create-intent response echo it so the client
        /// has a single source if desired. Not a secret.
        /// </summary>
        public string StripePublishableKey { get; set; } = string.Empty;

        /// <summary>
        /// Platform commission percentage, snapshotted onto every <c>Payment</c> at charge time
        /// (bookkeeping only — no organizer payouts / Stripe Connect). Defaults to 10.
        /// </summary>
        [Range(0, 100)]
        public decimal PlatformFeePercentage { get; set; } = 10m;

        /// <summary>ISO currency charged in Stripe. Always <c>bam</c> (displayed as "KM"); 2 decimal minor units.</summary>
        public string Currency { get; set; } = "bam";
    }
}
