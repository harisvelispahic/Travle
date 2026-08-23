using Travle.Model.Constants;
using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Authorization;
using Travle.Services.BookingStateMachine;
using Travle.Services.Database;
using Travle.Services.Notifications;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Linq.Dynamic.Core;

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
        private readonly IRefundService _refunds;
        private readonly INotificationDispatcher _notifications;
        private readonly IAppAuthorizationService _authorization;
        private readonly IValidator<PaymentIntentCreateRequest> _createValidator;
        private readonly BaseBookingState _states;
        private readonly ILogger<PaymentService> _logger;
        private readonly PaymentOptions _options;

        public PaymentService(
            TravleDbContext dbContext,
            IStripeService stripe,
            IRefundService refunds,
            INotificationDispatcher notifications,
            IAppAuthorizationService authorization,
            IValidator<PaymentIntentCreateRequest> createValidator,
            BaseBookingState states,
            ILogger<PaymentService> logger,
            IOptions<PaymentOptions> options)
        {
            _dbContext = dbContext;
            _stripe = stripe;
            _refunds = refunds;
            _notifications = notifications;
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

            // Reuse the latest retryable intent so tapping Pay again within the hold does not create a
            // duplicate. A Failed row counts as retryable: a declined card leaves the intent at
            // requires_payment_method, which Stripe intends to be re-confirmed with another card.
            var openPayment = booking.Payments
                .Where(p => p.Status is PaymentStatus.Pending or PaymentStatus.Failed)
                .OrderByDescending(p => p.Id)
                .FirstOrDefault();
            if (openPayment is not null)
            {
                var existing = await _stripe.GetPaymentIntentAsync(openPayment.StripePaymentIntentId, cancellationToken);
                switch (existing.Status)
                {
                    case "succeeded":
                        // Charged already, but the webhook hasn't promoted the booking yet — let the client refresh.
                        throw new ConflictException("This booking has already been paid.");
                    case "canceled":
                        // No longer usable: retire this row and fall through to create a fresh intent
                        // (the edit rides the SaveChanges that persists the new Payment below).
                        openPayment.Status = PaymentStatus.Failed;
                        break;
                    default:
                        // Handing the intent back reopens the attempt, so a previously declined row returns
                        // to Pending — that keeps "Pending = an attempt is in flight", which is what makes
                        // the webhook handlers replay-safe (they act only on a Pending row).
                        if (openPayment.Status == PaymentStatus.Failed)
                        {
                            openPayment.Status = PaymentStatus.Pending;
                            await _dbContext.SaveChangesAsync(cancellationToken);
                        }

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
            // (after a canceled intent) gets a new key because the payment-row count has grown. The seed is
            // the booking's random PaymentIdempotencyToken rather than its id, because ids are recycled by a
            // database re-seed while Stripe remembers a key (and the amount it first carried) for 24 hours —
            // a recycled id would collide with the previous occupant's key and be rejected.
            var idempotencyKey = $"pi-{booking.PaymentIdempotencyToken}-{booking.Payments.Count}";

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

            // Idempotency: only an OPEN attempt reacts to a succeeded event, and Failed counts as open.
            // Retrying a declined card inside the PaymentSheet re-confirms the SAME intent, so Stripe sends
            // payment_failed and afterwards succeeded for it; ignoring the second event would strand a real
            // charge on a booking that never gets promoted (and the orphaned-success branch below would
            // never be reached either). A replay finds the row already terminal — Succeeded (promoted) or
            // Refunded (an orphaned-success auto-refund, below) — and no-ops, so a replay never
            // re-promotes the booking nor clobbers the recorded refund.
            if (payment.Status is not (PaymentStatus.Pending or PaymentStatus.Failed))
            {
                _logger.LogDebug("Stripe webhook {EventId}: payment {PaymentId} already {Status}; skipping.",
                    evt.Id, payment.Id, payment.Status);
                return;
            }

            payment.Status = PaymentStatus.Succeeded;
            payment.SucceededAt = DateTime.UtcNow;

            // Never promote a booking on a charge that does not match what this row says was owed. The
            // intent was minted server-side with our amount and currency, and the row is looked up BY that
            // intent id, so a mismatch should be impossible — which is exactly why it is worth asserting:
            // if it ever happens, the safe outcome is to bank the money truthfully and give it straight
            // back, not to hand out a seat against an amount we did not price.
            var captured = MatchesRecordedCharge(payment, evt);

            if (captured && payment.Booking.StatusId == (int)BookingStatusCode.PaymentInProgress)
            {
                // The state machine owns the transition (and the PaymentSucceeded notification); its
                // SaveChanges also persists the Payment edit above (same DbContext scope).
                await _states.GetState(BookingStatusCode.PaymentInProgress).MarkPaidAsync(payment.Booking);
            }
            else
            {
                // Two ways to land here, both ending the same way — bank the charge, then give it back in
                // full. (1) The common race: the charge landed after the booking left PaymentInProgress — the
                // 15-minute hold expired (seats released, possibly resold) or the organizer cancelled the
                // slot. (2) The amount/currency guard above rejected the charge. Either way the money was
                // really captured, so record it truthfully and auto-refund: a traveler must never be charged
                // for a booking they cannot get. The refund runs post-commit (Stripe is never called inside a
                // DB transaction) and is idempotent, so a webhook replay is safe. The booking is not
                // resurrected — its seats may already be resold; the traveler is simply made whole.
                _logger.LogWarning(
                    "Stripe webhook {EventId}: payment {PaymentId} succeeded but it cannot be applied "
                    + "(amountMatches={Matches}, booking {BookingId} status {StatusId}); recording the charge and auto-refunding it in full.",
                    evt.Id, payment.Id, captured, payment.BookingId, payment.Booking.StatusId);
                await _dbContext.SaveChangesAsync(cancellationToken);
                await _refunds.RefundOrphanedPaymentAsync(
                    payment.Id,
                    "Payment captured after the booking was no longer active; automatic full refund.",
                    cancellationToken);
            }
        }

        // Confirms the charge Stripe reports is the one this row priced: same minor-unit amount, same
        // currency. Events that carry neither figure (an older API version, a trimmed test payload) are
        // accepted — the intent id already ties the event to this row, and refusing on a missing optional
        // field would strand real charges.
        private bool MatchesRecordedCharge(Payment payment, StripeWebhookEvent evt)
        {
            if (evt.AmountReceivedMinorUnits is not long received)
            {
                return true;
            }

            var expected = PaymentMath.ToMinorUnits(payment.Amount);
            if (received != expected)
            {
                _logger.LogError(
                    "Stripe webhook {EventId}: payment {PaymentId} captured {Received} minor units but the recorded amount is {Expected}.",
                    evt.Id, payment.Id, received, expected);
                return false;
            }

            if (!string.IsNullOrEmpty(evt.Currency)
                && !string.Equals(evt.Currency, payment.Currency, StringComparison.OrdinalIgnoreCase))
            {
                _logger.LogError(
                    "Stripe webhook {EventId}: payment {PaymentId} captured in '{Received}' but the recorded currency is '{Expected}'.",
                    evt.Id, payment.Id, evt.Currency, payment.Currency);
                return false;
            }

            return true;
        }

        private async Task HandlePaymentFailedAsync(StripeWebhookEvent evt, CancellationToken cancellationToken)
        {
            var payment = await LoadPaymentForWebhookAsync(evt, cancellationToken);
            if (payment is null)
            {
                return;
            }

            // Only an in-flight attempt reacts to a failure event. A row already Failed (a replayed event, or
            // a second decline on an attempt the traveler has not reopened), Succeeded, or Refunded is left
            // untouched: a late failure event for a since-succeeded intent is nonsensical and must never
            // clobber the recorded outcome, and a replay must not notify twice.
            if (payment.Status != PaymentStatus.Pending)
            {
                return;
            }

            payment.Status = PaymentStatus.Failed;
            _logger.LogInformation("Stripe webhook {EventId}: payment {PaymentId} failed ({Reason}).",
                evt.Id, payment.Id, evt.FailureMessage ?? "no reason given");

            // A declined card fails the ATTEMPT, never the booking. The seats are already held for 15
            // minutes, so the booking stays PaymentInProgress and the traveler can try another card until
            // that hold runs out; only the lifecycle sweep ever expires it. Stripe leaves the intent at
            // requires_payment_method, so the next CreateIntent hands the same one straight back.
            if (payment.Booking.StatusId == (int)BookingStatusCode.PaymentInProgress)
            {
                _notifications.Enqueue(payment.Booking.UserId, NotificationType.PaymentFailed,
                    "Payment failed",
                    $"{DescribeFailure(evt)} No money was taken. Your seats are still held, so you can open the booking and try another card before the payment hold runs out.",
                    payment.BookingId);
            }

            await _dbContext.SaveChangesAsync(cancellationToken);
        }

        // Stripe's own decline message ("Your card was declined.") is written for the cardholder, so it is
        // passed through when the event carries one; otherwise neutral copy stands in.
        private static string DescribeFailure(StripeWebhookEvent evt)
        {
            var message = evt.FailureMessage?.Trim();
            if (string.IsNullOrEmpty(message))
            {
                return "Your payment could not be completed.";
            }

            return message.EndsWith('.') ? message : message + ".";
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

        public async Task<PageResult<PaymentResponse>> SearchAsync(PaymentSearch search, CancellationToken cancellationToken = default)
        {
            _authorization.EnsureInRole(RoleNames.Admin);

            var query = ApplyFilters(_dbContext.Payments.AsNoTracking(), search);

            int? totalCount = null;
            if (search.IncludeTotalCount ?? false)
            {
                totalCount = await query.CountAsync(cancellationToken);
            }

            // Newest first by default; the table's sortable columns override via SortBy (entity paths).
            var sortBy = string.IsNullOrWhiteSpace(search.SortBy) ? "CreatedAt desc" : search.SortBy;
            try
            {
                query = query.OrderBy(sortBy);
            }
            catch (System.Linq.Dynamic.Core.Exceptions.ParseException)
            {
                throw new BusinessRuleException($"Invalid sort expression: '{search.SortBy}'.");
            }

            var page = search.Page is int p && p > 0 ? p : 1;
            var pageSize = Math.Clamp(search.PageSize ?? 10, 1, 100);
            query = query.Skip((page - 1) * pageSize).Take(pageSize);

            var items = await MapPaymentRowsAsync(query, cancellationToken);
            return new PageResult<PaymentResponse> { Items = items, TotalCount = totalCount };
        }

        /// <summary>
        /// Admin action: re-run a refund that a prior automatic attempt failed to complete (a rare Stripe
        /// error left the money owed). Reuses the idempotent <see cref="IRefundService"/> path — the amount
        /// is recomputed from the same tier, so a retry can never over-refund. The tier is reconstructed from
        /// who cancelled the booking: a self-cancellation is tiered by hours-before-start; any other cancel
        /// (organizer reject / slot cancel / organizer suspension) is a full refund.
        /// </summary>
        public async Task<PaymentResponse> RetryRefundAsync(int paymentId, CancellationToken cancellationToken = default)
        {
            _authorization.EnsureInRole(RoleNames.Admin);
            var adminId = _authorization.RequireUserId();

            var payment = await _dbContext.Payments
                .Include(p => p.Booking)
                .Include(p => p.Refunds)
                .FirstOrDefaultAsync(p => p.Id == paymentId, cancellationToken)
                ?? throw new NotFoundException("Payment", paymentId);

            if (payment.Booking.StatusId != (int)BookingStatusCode.Cancelled)
            {
                throw new BusinessRuleException("A refund can only be retried for a cancelled booking.");
            }
            if (payment.Status != PaymentStatus.Succeeded)
            {
                throw new BusinessRuleException("Only a captured payment can be refunded.");
            }
            if (payment.Refunds.Any())
            {
                throw new ConflictException("This payment has already been refunded.");
            }

            int? forcedPercentage = payment.Booking.CancelledByUserId == payment.Booking.UserId ? null : 100;

            await _refunds.RefundForBookingAsync(
                payment.BookingId, adminId, "Admin retried the owed refund.", forcedPercentage, cancellationToken);

            // Re-read the row so the client sees the advanced status / refund totals (or, if the retry failed
            // again, the still-owed flag and the fresh RefundFailed notification the refund service raised).
            return (await MapPaymentRowsAsync(
                    _dbContext.Payments.AsNoTracking().Where(p => p.Id == paymentId), cancellationToken))
                .FirstOrDefault()
                ?? throw new NotFoundException("Payment", paymentId);
        }

        // Projects payments to the admin DTO. Materializes with the raw enum then maps its name in memory
        // (EF can't translate enum.ToString()). RefundOwed marks a captured payment on a cancelled booking
        // that still carries no refund — the set the "Retry refund" action targets.
        private static async Task<List<PaymentResponse>> MapPaymentRowsAsync(
            IQueryable<Payment> query, CancellationToken cancellationToken)
        {
            var rows = await query
                .Select(p => new
                {
                    p.Id,
                    p.BookingId,
                    TravelerName = p.Booking.User.FirstName + " " + p.Booking.User.LastName,
                    TravelerUsername = p.Booking.User.Username,
                    TourName = p.Booking.TourSchedule.Tour.Name,
                    p.Amount,
                    p.Currency,
                    p.PlatformFeePercentage,
                    p.PlatformFeeAmount,
                    p.Status,
                    RefundedAmount = p.Refunds.Sum(r => (decimal?)r.Amount) ?? 0m,
                    RefundCount = p.Refunds.Count,
                    RefundOwed = p.Booking.StatusId == (int)BookingStatusCode.Cancelled
                                 && p.Status == PaymentStatus.Succeeded
                                 && !p.Refunds.Any(),
                    p.SucceededAt,
                    p.CreatedAt
                })
                .ToListAsync(cancellationToken);

            return rows.Select(r => new PaymentResponse
            {
                Id = r.Id,
                BookingId = r.BookingId,
                TravelerName = r.TravelerName,
                TravelerUsername = r.TravelerUsername,
                TourName = r.TourName,
                Amount = r.Amount,
                Currency = r.Currency,
                PlatformFeePercentage = r.PlatformFeePercentage,
                PlatformFeeAmount = r.PlatformFeeAmount,
                Status = r.Status.ToString(),
                RefundedAmount = r.RefundedAmount,
                RefundCount = r.RefundCount,
                RefundOwed = r.RefundOwed,
                SucceededAt = r.SucceededAt,
                CreatedAt = r.CreatedAt
            }).ToList();
        }

        public async Task<PaymentSummaryResponse> GetSummaryAsync(PaymentSearch search, CancellationToken cancellationToken = default)
        {
            _authorization.EnsureInRole(RoleNames.Admin);

            var filtered = ApplyFilters(_dbContext.Payments.AsNoTracking(), search);

            // "Captured" = money actually taken (charged and possibly later refunded).
            var captured = filtered.Where(p => p.Status == PaymentStatus.Succeeded
                                               || p.Status == PaymentStatus.Refunded
                                               || p.Status == PaymentStatus.PartiallyRefunded);

            var capturedCount = await captured.CountAsync(cancellationToken);
            var grossRevenue = await captured.SumAsync(p => (decimal?)p.Amount, cancellationToken) ?? 0m;

            var refunds = filtered.SelectMany(p => p.Refunds);
            var totalRefunded = await refunds.SumAsync(r => (decimal?)r.Amount, cancellationToken) ?? 0m;
            var refundCount = await refunds.CountAsync(cancellationToken);

            var netRevenue = grossRevenue - totalRefunded;

            // Commission is earned only on funds the platform actually kept. A refund gives money back to
            // the traveler, so it must shrink the commission too — otherwise the platform would appear to
            // earn 10% on amounts it returned. Each payment's snapshotted fee is scaled by the fraction of
            // its charge that was retained (refund tiers apply to the whole charge, fee included), then
            // summed at the DB and rounded once for display. Amount is always > 0 for a captured payment
            // (a booking with no payable amount never produces a Payment row), so the division is safe.
            var netCommissionRaw = await captured.SumAsync(
                p => (decimal?)(p.PlatformFeeAmount
                    * (p.Amount - (p.Refunds.Sum(r => (decimal?)r.Amount) ?? 0m))
                    / p.Amount),
                cancellationToken) ?? 0m;
            var commission = Math.Round(netCommissionRaw, 2, MidpointRounding.AwayFromZero);

            return new PaymentSummaryResponse
            {
                CapturedCount = capturedCount,
                GrossRevenue = grossRevenue,
                PlatformCommission = commission,
                OrganizerShare = netRevenue - commission,
                TotalRefunded = totalRefunded,
                RefundCount = refundCount,
                NetRevenue = netRevenue,
                Currency = _options.Currency
            };
        }

        private static IQueryable<Payment> ApplyFilters(IQueryable<Payment> query, PaymentSearch search)
        {
            if (search.Status is int status)
            {
                query = query.Where(p => p.Status == (PaymentStatus)status);
            }
            if (search.FromDate is DateTime from)
            {
                query = query.Where(p => p.CreatedAt >= from);
            }
            if (search.ToDate is DateTime to)
            {
                query = query.Where(p => p.CreatedAt < to);
            }
            if (!string.IsNullOrWhiteSpace(search.Text))
            {
                var text = search.Text.Trim();
                query = query.Where(p =>
                    p.Booking.User.Username.Contains(text)
                    || (p.Booking.User.FirstName + " " + p.Booking.User.LastName).Contains(text)
                    || p.Booking.TourSchedule.Tour.Name.Contains(text));
            }
            return query;
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
