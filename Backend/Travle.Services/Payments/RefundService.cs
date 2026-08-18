using Travle.Model.Exceptions;
using Travle.Services.Database;
using Travle.Services.Notifications;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Travle.Services.Payments
{
    /// <summary>
    /// Post-commit refund executor (see <see cref="IRefundService"/>). Computes the tier, calls the Stripe
    /// Refund API against the <b>actually charged</b> amount, writes the <c>Refund</c> row, advances the
    /// <c>Payment</c> status and notifies the traveler — all after the booking is already Cancelled, and
    /// never inside a DB transaction (the single <c>SaveChanges</c> per refund is atomic on its own).
    /// </summary>
    public sealed class RefundService : IRefundService
    {
        private readonly TravleDbContext _dbContext;
        private readonly IStripeService _stripe;
        private readonly INotificationDispatcher _notifications;
        private readonly ILogger<RefundService> _logger;

        public RefundService(
            TravleDbContext dbContext,
            IStripeService stripe,
            INotificationDispatcher notifications,
            ILogger<RefundService> logger)
        {
            _dbContext = dbContext;
            _stripe = stripe;
            _notifications = notifications;
            _logger = logger;
        }

        public async Task RefundForBookingAsync(
            int bookingId, int initiatedByUserId, string reason, int? forcedPercentage, CancellationToken cancellationToken = default)
        {
            var payment = await LoadRefundablePaymentsQuery()
                .Where(p => p.BookingId == bookingId)
                .OrderByDescending(p => p.Id)
                .FirstOrDefaultAsync(cancellationToken);

            if (payment is null)
            {
                // Nothing was ever charged for this booking (e.g. it was cancelled while still in the hold).
                _logger.LogDebug("No charged payment for booking {BookingId}; nothing to refund.", bookingId);
                return;
            }

            await IssueRefundAsync(payment, forcedPercentage, initiatedByUserId, reason, cancellationToken);
        }

        public async Task RefundForScheduleCancellationAsync(
            int scheduleId, int initiatedByUserId, string reason, CancellationToken cancellationToken = default)
        {
            var payments = await LoadRefundablePaymentsQuery()
                .Where(p => p.Booking.TourScheduleId == scheduleId)
                .ToListAsync(cancellationToken);

            foreach (var payment in payments)
            {
                // The organizer retired the whole slot ⇒ always a full refund.
                await IssueRefundAsync(payment, forcedPercentage: 100, initiatedByUserId, reason, cancellationToken);
            }
        }

        public async Task RefundOrphanedPaymentAsync(
            int paymentId, string reason, CancellationToken cancellationToken = default)
        {
            var payment = await _dbContext.Payments
                .Include(p => p.Booking)
                .FirstOrDefaultAsync(p => p.Id == paymentId, cancellationToken);

            if (payment is null)
            {
                _logger.LogWarning("Orphaned-payment refund: payment {PaymentId} not found; nothing to refund.", paymentId);
                return;
            }

            // Only a captured charge can be refunded (defensive: the webhook sets Succeeded before calling in).
            if (payment.Status != PaymentStatus.Succeeded)
            {
                _logger.LogDebug("Orphaned-payment refund: payment {PaymentId} is {Status}, not Succeeded; skipping.",
                    paymentId, payment.Status);
                return;
            }

            // Full auto-refund, attributed to the traveler themselves (no admin/organizer initiated it). The
            // idempotency guard inside IssueRefundAsync makes a webhook replay safe (never a double refund).
            await IssueRefundAsync(
                payment,
                forcedPercentage: 100,
                initiatedByUserId: payment.Booking.UserId,
                reason,
                cancellationToken,
                notificationText: "Your payment was received after the booking hold had already expired and its seats were released, so a full refund has been issued to your original payment method.");
        }

        // Seeded/demo payments carry a fabricated "pi_seed…" intent id (see BulkSeeder / migration seed) that
        // was never created in Stripe. Refunding one must skip the Stripe call and record bookkeeping only.
        private const string SyntheticIntentPrefix = "pi_seed";

        private static bool IsSyntheticPayment(Payment payment)
            => payment.StripePaymentIntentId.StartsWith(SyntheticIntentPrefix, StringComparison.Ordinal);

        // Paid, now-cancelled bookings that don't already carry a refund — the set that is owed a refund.
        private IQueryable<Payment> LoadRefundablePaymentsQuery()
            => _dbContext.Payments
                .Include(p => p.Booking).ThenInclude(b => b.TourSchedule)
                .Where(p => p.Status == PaymentStatus.Succeeded
                            && p.Booking.StatusId == (int)BookingStatusCode.Cancelled
                            && !p.Refunds.Any());

        private async Task IssueRefundAsync(
            Payment payment, int? forcedPercentage, int initiatedByUserId, string reason, CancellationToken cancellationToken,
            string? notificationText = null)
        {
            // Idempotency guard (belt-and-suspenders alongside the query filter): never refund twice.
            var alreadyRefunded = await _dbContext.Refunds.AnyAsync(r => r.PaymentId == payment.Id, cancellationToken);
            if (alreadyRefunded)
            {
                _logger.LogDebug("Payment {PaymentId} already has a refund; skipping.", payment.Id);
                return;
            }

            var percentage = forcedPercentage
                ?? await PaymentMath.ResolveRefundPercentageAsync(
                    _dbContext, payment.Booking.TourSchedule.StartsAt, DateTime.UtcNow, cancellationToken);
            var amount = PaymentMath.RefundAmount(payment.Amount, percentage);

            try
            {
                var stripeRefundId = string.Empty;
                if (amount > 0)
                {
                    if (IsSyntheticPayment(payment))
                    {
                        // Seeded/demo payment: its PaymentIntent (pi_seed…) never existed in Stripe, so there
                        // is nothing to call. Record the refund as bookkeeping only — exactly like a 0% tier —
                        // so the demo's cancel / organizer-reject / organizer-suspension flows behave correctly
                        // without a flood of "No such payment_intent" errors. Real (app-made) payments still
                        // hit Stripe below.
                        _logger.LogInformation(
                            "Payment {PaymentId} is a seeded demo payment ({IntentId}); recording a bookkeeping-only refund (no Stripe call).",
                            payment.Id, payment.StripePaymentIntentId);
                    }
                    else
                    {
                        // The idempotency key is derived from the payment, so even if this succeeds on Stripe but
                        // the SaveChanges below fails, a later retry returns the SAME refund (never a double refund).
                        var refund = await _stripe.CreateRefundAsync(
                            payment.StripePaymentIntentId,
                            PaymentMath.ToMinorUnits(amount),
                            $"refund-payment-{payment.Id}",
                            cancellationToken);
                        stripeRefundId = refund.Id;
                    }
                    payment.Status = percentage >= 100 ? PaymentStatus.Refunded : PaymentStatus.PartiallyRefunded;
                }

                _dbContext.Refunds.Add(new Refund
                {
                    PaymentId = payment.Id,
                    StripeRefundId = stripeRefundId,
                    Amount = amount,
                    PercentageApplied = percentage,
                    Reason = reason,
                    InitiatedByUserId = initiatedByUserId
                });

                // Notify the traveler only when money actually comes back (a 0% tier records the row silently).
                if (amount > 0)
                {
                    _notifications.Enqueue(payment.Booking.UserId, NotificationType.RefundIssued,
                        "Refund issued",
                        notificationText ?? $"A refund of {amount:0.00} KM ({percentage}%) has been issued to your original payment method.",
                        payment.BookingId, alsoEmail: true);
                }

                await _dbContext.SaveChangesAsync(cancellationToken);
                _logger.LogInformation(
                    "Refunded {Amount} KM ({Percentage}%) for booking {BookingId} (payment {PaymentId}).",
                    amount, percentage, payment.BookingId, payment.Id);
            }
            catch (PaymentException ex)
            {
                // Best-effort: the cancellation itself has already committed, so a Stripe refund failure must
                // not surface as "the cancellation failed". Logged for reconciliation; the missing Refund row
                // leaves the payment eligible for a safe (idempotent) retry.
                _logger.LogError(ex,
                    "Refund of {Amount} KM ({Percentage}%) failed for booking {BookingId} (payment {PaymentId}); the cancellation stands and the refund is owed.",
                    amount, percentage, payment.BookingId, payment.Id);

                await NotifyRefundOwedAsync(payment, amount, percentage, cancellationToken);
            }
        }

        // A Stripe refund errored, so the money is still owed. Reassure the traveler (they were told a refund
        // was coming) and alert every admin to retry it from the payments screen. The notification rows are
        // the only pending changes here — the failed try added nothing to the context — so a dedicated
        // SaveChanges persists them; the request/worker flush then pushes + emails them.
        private async Task NotifyRefundOwedAsync(
            Payment payment, decimal amount, int percentage, CancellationToken cancellationToken)
        {
            _notifications.Enqueue(payment.Booking.UserId, NotificationType.General,
                "Refund delayed",
                $"We hit a problem processing your refund for booking #{payment.BookingId}. Our team has been notified and will make sure it is completed.",
                payment.BookingId);

            var adminIds = await NotificationRecipients.AdminUserIdsAsync(_dbContext, cancellationToken);
            foreach (var adminId in adminIds)
            {
                _notifications.Enqueue(adminId, NotificationType.RefundFailed,
                    "Refund failed — action needed",
                    $"An automatic refund of {amount:0.00} KM ({percentage}%) for booking #{payment.BookingId} failed and is owed to the traveler. Retry it from the Payments screen.",
                    payment.BookingId, alsoEmail: true);
            }

            await _dbContext.SaveChangesAsync(cancellationToken);
        }
    }
}
