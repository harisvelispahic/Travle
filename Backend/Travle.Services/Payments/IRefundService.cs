namespace Travle.Services.Payments
{
    /// <summary>
    /// Executes refunds after a booking has already been moved to Cancelled by the state machine. Kept
    /// separate from the state transition on purpose: a refund is a <b>payment</b> side-effect (a Stripe
    /// network call + a <c>Refund</c> row + a <c>Payment</c> status change), and Stripe must never be called
    /// while a DB transaction is open — so the orchestrators (BookingService, TourService) commit the
    /// cancellation first, then call in here. Every method is idempotent: a booking/payment that already
    /// carries a <c>Refund</c> is skipped, so a retry never double-refunds.
    /// </summary>
    public interface IRefundService
    {
        /// <summary>
        /// Refunds the charged amount for a single cancelled booking. <paramref name="forcedPercentage"/>
        /// is 100 for an organizer rejection; <c>null</c> means "resolve the tier from how far ahead of the
        /// schedule the traveler cancelled" (user cancellation). A booking with no succeeded payment (never
        /// paid) is a no-op. A 0% outcome still records a zero <c>Refund</c> row for audit.
        /// </summary>
        Task RefundForBookingAsync(
            int bookingId, int initiatedByUserId, string reason, int? forcedPercentage, CancellationToken cancellationToken = default);

        /// <summary>
        /// Refunds every paid, now-cancelled booking on a slot the organizer retired, at 100% each. Runs
        /// after the slot-cancel transaction has committed; skips any booking already refunded.
        /// </summary>
        Task RefundForScheduleCancellationAsync(
            int scheduleId, int initiatedByUserId, string reason, CancellationToken cancellationToken = default);

        /// <summary>
        /// Full auto-refund for a payment that was captured after its booking was no longer consumable — a
        /// <c>payment_intent.succeeded</c> that landed after the 15-minute hold expired (seats released, maybe
        /// resold) or the slot was cancelled. Called by the webhook once the charge is recorded, so the
        /// traveler is never left charged with nothing. Attributed to the traveler themselves (no
        /// admin/organizer initiated it); idempotent (a payment that already carries a <c>Refund</c> is
        /// skipped) and, like the other refunds, a post-commit Stripe call outside any DB transaction.
        /// </summary>
        Task RefundOrphanedPaymentAsync(
            int paymentId, string reason, CancellationToken cancellationToken = default);
    }
}
