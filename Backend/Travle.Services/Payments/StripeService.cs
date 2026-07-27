using Travle.Model.Exceptions;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Stripe;
using System.Net;

namespace Travle.Services.Payments
{
    /// <summary>
    /// The single place that calls Stripe.net. Uses a DI-friendly <see cref="StripeClient"/> built from the
    /// configured test key (no global static <c>StripeConfiguration.ApiKey</c>), so nothing else in the app
    /// needs the SDK. Known Stripe failures are translated to <see cref="PaymentException"/> (a clean 402)
    /// rather than surfacing the raw SDK exception as a 500.
    /// </summary>
    public sealed class StripeService : IStripeService
    {
        // Stripe's stable public event-type names (compared directly so we don't depend on the SDK's
        // constants class, whose name has shifted across Stripe.net major versions).
        private const string PaymentIntentSucceededEvent = "payment_intent.succeeded";
        private const string PaymentIntentPaymentFailedEvent = "payment_intent.payment_failed";

        private readonly PaymentIntentService _paymentIntents;
        // Fully qualified: our own Travle.Services.Payments.RefundService lives in this namespace too.
        private readonly Stripe.RefundService _refunds;
        private readonly string _webhookSecret;
        private readonly ILogger<StripeService> _logger;

        public StripeService(IOptions<PaymentOptions> options, ILogger<StripeService> logger)
        {
            var client = new StripeClient(options.Value.StripeSecretKey);
            _paymentIntents = new PaymentIntentService(client);
            _refunds = new Stripe.RefundService(client);
            _webhookSecret = options.Value.StripeWebhookSecret;
            _logger = logger;
        }

        public async Task<StripePaymentIntentResult> CreatePaymentIntentAsync(
            long amountMinorUnits,
            string currency,
            IReadOnlyDictionary<string, string> metadata,
            string idempotencyKey,
            CancellationToken cancellationToken = default)
        {
            var createOptions = new PaymentIntentCreateOptions
            {
                Amount = amountMinorUnits,
                Currency = currency,
                // Card-only keeps the mobile PaymentSheet flow deterministic: no redirect-based methods
                // that would need a return URL, and no dashboard payment-method configuration required.
                PaymentMethodTypes = new List<string> { "card" },
                Metadata = new Dictionary<string, string>(metadata)
            };

            // The idempotency key makes a retried create (network blip, double-tap) return the SAME intent
            // instead of a duplicate charge object.
            var requestOptions = new RequestOptions { IdempotencyKey = idempotencyKey };

            try
            {
                var intent = await _paymentIntents.CreateAsync(createOptions, requestOptions, cancellationToken);
                return Map(intent);
            }
            catch (StripeException ex)
            {
                _logger.LogError(ex, "Stripe rejected PaymentIntent creation for {Currency} {Amount}.",
                    currency, amountMinorUnits);
                throw new PaymentException("The payment could not be started. Please try again.", ex);
            }
        }

        public async Task<StripePaymentIntentResult> GetPaymentIntentAsync(
            string paymentIntentId,
            CancellationToken cancellationToken = default)
        {
            try
            {
                var intent = await _paymentIntents.GetAsync(paymentIntentId, cancellationToken: cancellationToken);
                return Map(intent);
            }
            catch (StripeException ex)
            {
                _logger.LogError(ex, "Stripe could not retrieve PaymentIntent {IntentId}.", paymentIntentId);
                throw new PaymentException("The payment could not be retrieved. Please try again.", ex);
            }
        }

        public StripeWebhookEvent ConstructWebhookEvent(string json, string signatureHeader)
        {
            if (string.IsNullOrEmpty(_webhookSecret))
            {
                // Fail closed: without the signing secret we cannot verify the caller, so we never trust it.
                _logger.LogError("Stripe webhook received but Payments__StripeWebhookSecret is not configured.");
                throw new PaymentException("Webhook verification is not configured.", HttpStatusCode.InternalServerError);
            }

            Event stripeEvent;
            try
            {
                // throwOnApiVersionMismatch:false tolerates the Stripe CLI / dashboard sending events on a
                // slightly different API version than the SDK — the signature is what we actually rely on.
                stripeEvent = EventUtility.ConstructEvent(
                    json, signatureHeader, _webhookSecret, throwOnApiVersionMismatch: false);
            }
            catch (StripeException ex)
            {
                _logger.LogWarning(ex, "Rejected a Stripe webhook with an invalid signature.");
                throw new PaymentException("Invalid webhook signature.", ex, HttpStatusCode.BadRequest);
            }

            var type = stripeEvent.Type switch
            {
                PaymentIntentSucceededEvent => StripeWebhookEventType.PaymentSucceeded,
                PaymentIntentPaymentFailedEvent => StripeWebhookEventType.PaymentFailed,
                _ => StripeWebhookEventType.Ignored
            };

            var intent = stripeEvent.Data.Object as PaymentIntent;
            return new StripeWebhookEvent(
                stripeEvent.Id, type, intent?.Id, intent?.LastPaymentError?.Message);
        }

        public async Task<StripeRefundResult> CreateRefundAsync(
            string paymentIntentId,
            long amountMinorUnits,
            string idempotencyKey,
            CancellationToken cancellationToken = default)
        {
            var createOptions = new RefundCreateOptions
            {
                PaymentIntent = paymentIntentId,
                Amount = amountMinorUnits
            };
            var requestOptions = new RequestOptions { IdempotencyKey = idempotencyKey };

            try
            {
                var refund = await _refunds.CreateAsync(createOptions, requestOptions, cancellationToken);
                return new StripeRefundResult(refund.Id, refund.Status);
            }
            catch (StripeException ex)
            {
                _logger.LogError(ex, "Stripe refund failed for intent {IntentId} ({Amount} minor units).",
                    paymentIntentId, amountMinorUnits);
                throw new PaymentException("The refund could not be processed.", ex);
            }
        }

        private static StripePaymentIntentResult Map(PaymentIntent intent)
            => new(intent.Id, intent.ClientSecret, intent.Status);
    }
}
