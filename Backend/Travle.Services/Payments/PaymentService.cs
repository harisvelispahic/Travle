using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Services.Authorization;
using Travle.Services.BookingStateMachine;
using Travle.Services.Database;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Travle.Services.Payments
{
    /// <summary>
    /// The payment "context". Reads the booking, enforces ownership and the PaymentInProgress precondition,
    /// computes the charge amount and commission snapshot from the <b>stored</b> booking total (never the
    /// client), and drives <see cref="IStripeService"/> to create/reuse a PaymentIntent. The unique index
    /// on <c>Payment.StripePaymentIntentId</c> plus the "already succeeded ⇒ conflict" check are the
    /// double-payment guard; the booking is promoted to Pending only by the webhook (6b).
    /// </summary>
    public sealed class PaymentService : IPaymentService
    {
        private readonly TravleDbContext _dbContext;
        private readonly IStripeService _stripe;
        private readonly IAppAuthorizationService _authorization;
        private readonly IValidator<PaymentIntentCreateRequest> _createValidator;
        private readonly BaseBookingState _states;
        private readonly ILogger<PaymentService> _logger;
        private readonly PaymentOptions _options;

        public PaymentService(
            TravleDbContext dbContext,
            IStripeService stripe,
            IAppAuthorizationService authorization,
            IValidator<PaymentIntentCreateRequest> createValidator,
            BaseBookingState states,
            ILogger<PaymentService> logger,
            IOptions<PaymentOptions> options)
        {
            _dbContext = dbContext;
            _stripe = stripe;
            _authorization = authorization;
            _createValidator = createValidator;
            _states = states;
            _logger = logger;
            _options = options.Value;
        }

        public async Task<PaymentIntentResponse> CreateIntentAsync(
            PaymentIntentCreateRequest request,
            CancellationToken cancellationToken = default)
        {
            await _createValidator.ValidateAndThrowAsync(request, cancellationToken);
            var userId = _authorization.RequireUserId();

            var booking = await _dbContext.Bookings
                .Include(b => b.Payments)
                .FirstOrDefaultAsync(b => b.Id == request.BookingId, cancellationToken)
                ?? throw new NotFoundException("Booking", request.BookingId);

            // Only the booking's own traveler may pay for it (never trust the client for the user).
            if (booking.UserId != userId)
            {
                throw new ForbiddenException("You can only pay for your own booking.");
            }

            if (booking.StatusId != (int)BookingStatusCode.PaymentInProgress)
            {
                throw new BusinessRuleException("This booking is not awaiting payment.");
            }

            if (booking.ExpiresAt is DateTime expiry && expiry <= DateTime.UtcNow)
            {
                throw new BusinessRuleException("The 15-minute payment hold has expired. Please book again.");
            }

            if (booking.TotalAmount <= 0)
            {
                throw new PaymentException("This booking has no payable amount.");
            }

            // Double-payment guard: a booking can be charged at most once.
            if (booking.Payments.Any(p => p.Status == PaymentStatus.Succeeded))
            {
                throw new ConflictException("This booking has already been paid.");
            }

            var currency = _options.Currency;

            // Reuse an already-open intent so tapping Pay again within the hold does not create a duplicate.
            var openPayment = booking.Payments.FirstOrDefault(p => p.Status == PaymentStatus.Pending);
            if (openPayment is not null)
            {
                var existing = await _stripe.GetPaymentIntentAsync(openPayment.StripePaymentIntentId, cancellationToken);
                switch (existing.Status)
                {
                    case "succeeded":
                        // Charged already, but the webhook hasn't promoted the booking yet — let the client refresh.
                        throw new ConflictException("This booking has already been paid.");
                    case "canceled":
                        // No longer usable: retire this row and fall through to create a fresh intent.
                        openPayment.Status = PaymentStatus.Failed;
                        break;
                    default:
                        return BuildResponse(booking, openPayment, existing.ClientSecret);
                }
            }

            var amountMinorUnits = PaymentMath.ToMinorUnits(booking.TotalAmount);
            var feePercentage = _options.PlatformFeePercentage;
            var feeAmount = Math.Round(booking.TotalAmount * feePercentage / 100m, 2, MidpointRounding.AwayFromZero);

            var metadata = new Dictionary<string, string>
            {
                ["bookingId"] = booking.Id.ToString(),
                ["userId"] = booking.UserId.ToString()
            };

            // Stable per attempt: a duplicate simultaneous create returns the same intent; a fresh attempt
            // (after a canceled intent) gets a new key because the payment-row count has grown.
            var idempotencyKey = $"pi-booking-{booking.Id}-{booking.Payments.Count}";

            var intent = await _stripe.CreatePaymentIntentAsync(
                amountMinorUnits, currency, metadata, idempotencyKey, cancellationToken);

            var payment = new Payment
            {
                BookingId = booking.Id,
                StripePaymentIntentId = intent.Id,
                Amount = booking.TotalAmount,
                Currency = currency,
                PlatformFeePercentage = feePercentage,
                PlatformFeeAmount = feeAmount,
                Status = PaymentStatus.Pending
            };
            _dbContext.Payments.Add(payment);
            await _dbContext.SaveChangesAsync(cancellationToken);

            return BuildResponse(booking, payment, intent.ClientSecret);
        }

        public async Task HandleWebhookAsync(string json, string signatureHeader, CancellationToken cancellationToken = default)
        {
            // Trust boundary: throws (400) if the signature does not match the configured secret.
            var evt = _stripe.ConstructWebhookEvent(json, signatureHeader);

            switch (evt.Type)
            {
                case StripeWebhookEventType.PaymentSucceeded:
                    await HandlePaymentSucceededAsync(evt, cancellationToken);
                    break;
                case StripeWebhookEventType.PaymentFailed:
                    await HandlePaymentFailedAsync(evt, cancellationToken);
                    break;
                default:
                    // Subscribed-but-uninteresting events (or an intent we didn't create): acknowledge, no-op.
                    _logger.LogDebug("Ignoring Stripe webhook {EventId} of an unhandled type.", evt.Id);
                    break;
            }
        }

        private async Task HandlePaymentSucceededAsync(StripeWebhookEvent evt, CancellationToken cancellationToken)
        {
            var payment = await LoadPaymentForWebhookAsync(evt, cancellationToken);
            if (payment is null)
            {
                return;
            }

            // Idempotency: a replayed succeeded event finds the payment already recorded — no double effect.
            if (payment.Status == PaymentStatus.Succeeded)
            {
                _logger.LogDebug("Stripe webhook {EventId}: payment {PaymentId} already succeeded; skipping.",
                    evt.Id, payment.Id);
                return;
            }

            payment.Status = PaymentStatus.Succeeded;
            payment.SucceededAt = DateTime.UtcNow;

            if (payment.Booking.StatusId == (int)BookingStatusCode.PaymentInProgress)
            {
                // The state machine owns the transition (and the PaymentSucceeded notification); its
                // SaveChanges also persists the Payment edit above (same DbContext scope).
                await _states.GetState(BookingStatusCode.PaymentInProgress).MarkPaidAsync(payment.Booking);
            }
            else
            {
                // Rare race: the payment landed after the hold already expired (or was otherwise moved).
                // Record the payment truthfully; the booking is not resurrected here (see docs §known edges).
                _logger.LogWarning(
                    "Stripe webhook {EventId}: payment {PaymentId} succeeded but booking {BookingId} is in status {StatusId}; recorded payment only.",
                    evt.Id, payment.Id, payment.BookingId, payment.Booking.StatusId);
                await _dbContext.SaveChangesAsync(cancellationToken);
            }
        }

        private async Task HandlePaymentFailedAsync(StripeWebhookEvent evt, CancellationToken cancellationToken)
        {
            var payment = await LoadPaymentForWebhookAsync(evt, cancellationToken);
            if (payment is null)
            {
                return;
            }

            // Never override a success (a late failure event for a since-succeeded intent is nonsensical).
            if (payment.Status == PaymentStatus.Succeeded)
            {
                return;
            }
            if (payment.Status == PaymentStatus.Failed)
            {
                return;
            }

            payment.Status = PaymentStatus.Failed;
            _logger.LogInformation("Stripe webhook {EventId}: payment {PaymentId} failed ({Reason}).",
                evt.Id, payment.Id, evt.FailureMessage ?? "no reason given");

            if (payment.Booking.StatusId == (int)BookingStatusCode.PaymentInProgress)
            {
                // Release the held seats immediately rather than waiting out the 15-minute hold (the
                // lifecycle diagram's "payment failed → Expired"). Expire's SaveChanges persists the edit above.
                await _states.GetState(BookingStatusCode.PaymentInProgress).ExpireAsync(payment.Booking);
            }
            else
            {
                await _dbContext.SaveChangesAsync(cancellationToken);
            }
        }

        // Loads the tracked Payment (with its Booking) for the intent the event refers to. A missing intent
        // id or unknown payment is logged and treated as a no-op so the webhook still returns 200 (Stripe
        // would otherwise retry a genuinely-unactionable event indefinitely).
        private async Task<Payment?> LoadPaymentForWebhookAsync(StripeWebhookEvent evt, CancellationToken cancellationToken)
        {
            if (string.IsNullOrEmpty(evt.PaymentIntentId))
            {
                _logger.LogWarning("Stripe webhook {EventId} carried no PaymentIntent id; ignoring.", evt.Id);
                return null;
            }

            var payment = await _dbContext.Payments
                .Include(p => p.Booking)
                .FirstOrDefaultAsync(p => p.StripePaymentIntentId == evt.PaymentIntentId, cancellationToken);

            if (payment is null)
            {
                _logger.LogWarning("Stripe webhook {EventId}: no payment found for intent {IntentId}.",
                    evt.Id, evt.PaymentIntentId);
            }

            return payment;
        }

        private PaymentIntentResponse BuildResponse(Booking booking, Payment payment, string clientSecret)
            => new()
            {
                BookingId = booking.Id,
                PaymentId = payment.Id,
                ClientSecret = clientSecret,
                PublishableKey = _options.StripePublishableKey,
                Amount = booking.TotalAmount,
                Currency = payment.Currency
            };
    }
}
