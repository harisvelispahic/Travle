namespace Travle.Services.Payments
{
    /// <summary>
    /// Executes refunds after a booking has already been moved to Cancelled by the state machine. Kept
    /// separate from the state transition on purpose: a refund is a <b>payment</b> side-effect (a Stripe
    /// network call + a <c>Refund</c> row + a <c>Payment</c> status change), and Stripe must never be called
    /// while a DB transaction is open — so the orchestrators (BookingService, TourService) commit the
    /// cancellation first, then call in here. Every method is idempotent: a booking/payment that already
    /// carries a <c>Refund</c> is skipped, so a retry never double-refunds.
    ///
    /// This service decides <b>nothing</b> about how much is owed. The cancelling transition freezes the
    /// percentage and amount onto the booking as it cancels it; these methods only carry that recorded
    /// obligation out to Stripe. That is what makes a retry safe: the first attempt and every later one
    /// execute the same figure, however much time has passed.
    /// </summary>
    public interface IRefundService
    {
        /// <summary>
        /// Executes the refund obligation recorded on a cancelled booking. A booking with no succeeded
        /// payment (never paid) is a no-op. A 0% obligation still records a zero <c>Refund</c> row for audit.
        /// </summary>
        Task RefundForBookingAsync(
            int bookingId, int initiatedByUserId, string reason, CancellationToken cancellationToken = default);

        /// <summary>
        /// Executes the recorded obligation for every paid, now-cancelled booking on a slot the organizer
        /// retired (each snapshotted at 100% by the slot-cancel transition). Runs after that transaction has
        /// committed; skips any booking already refunded.
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
