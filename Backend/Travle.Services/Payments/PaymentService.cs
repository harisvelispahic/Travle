using Travle.Model.Constants;
using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Authorization;
using Travle.Services.BookingStateMachine;
using Travle.Services.Database;
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
        private readonly IAppAuthorizationService _authorization;
        private readonly IValidator<PaymentIntentCreateRequest> _createValidator;
        private readonly BaseBookingState _states;
        private readonly ILogger<PaymentService> _logger;
        private readonly PaymentOptions _options;

        public PaymentService(
            TravleDbContext dbContext,
            IStripeService stripe,
            IRefundService refunds,
            IAppAuthorizationService authorization,
            IValidator<PaymentIntentCreateRequest> createValidator,
            BaseBookingState states,
            ILogger<PaymentService> logger,
            IOptions<PaymentOptions> options)
        {
            _dbContext = dbContext;
            _stripe = stripe;
            _refunds = refunds;
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

            // Idempotency: only a still-Pending payment reacts to a succeeded event. A replay finds it
            // already terminal — Succeeded (promoted) or Refunded (an orphaned-success auto-refund, below) —
            // and no-ops, so a replay never re-promotes the booking nor clobbers the recorded refund.
            if (payment.Status != PaymentStatus.Pending)
            {
                _logger.LogDebug("Stripe webhook {EventId}: payment {PaymentId} already {Status}; skipping.",
                    evt.Id, payment.Id, payment.Status);
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
                // Rare race: the charge landed after the booking left PaymentInProgress — the 15-minute hold
                // expired (seats released, possibly resold) or the organizer cancelled the slot. The money was
                // really captured, so record it truthfully, then auto-refund it in full: a traveler must never
                // be charged for a booking they cannot get. The refund runs post-commit (Stripe is never called
                // inside a DB transaction) and is idempotent, so a webhook replay is safe. The booking is not
                // resurrected — its seats may already be resold; the traveler is simply made whole.
                _logger.LogWarning(
                    "Stripe webhook {EventId}: payment {PaymentId} succeeded but booking {BookingId} is in status {StatusId}; recording the charge and auto-refunding it in full.",
                    evt.Id, payment.Id, payment.BookingId, payment.Booking.StatusId);
                await _dbContext.SaveChangesAsync(cancellationToken);
                await _refunds.RefundOrphanedPaymentAsync(
                    payment.Id,
                    "Payment captured after the booking was no longer active; automatic full refund.",
                    cancellationToken);
            }
        }

        private async Task HandlePaymentFailedAsync(StripeWebhookEvent evt, CancellationToken cancellationToken)
        {
            var payment = await LoadPaymentForWebhookAsync(evt, cancellationToken);
            if (payment is null)
            {
                return;
            }

            // Only a still-Pending payment reacts to a failure event. A payment already terminal — Succeeded,
            // Failed, or Refunded (an orphaned-success auto-refund) — is left untouched: a late failure event
            // for a since-succeeded intent is nonsensical and must never clobber the recorded outcome.
            if (payment.Status != PaymentStatus.Pending)
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

            // Materialize with the raw enum, then map its name in memory (EF can't translate enum.ToString()).
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
                    p.SucceededAt,
                    p.CreatedAt
                })
                .ToListAsync(cancellationToken);

            var items = rows.Select(r => new PaymentResponse
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
                SucceededAt = r.SucceededAt,
                CreatedAt = r.CreatedAt
            }).ToList();

            return new PageResult<PaymentResponse> { Items = items, TotalCount = totalCount };
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
