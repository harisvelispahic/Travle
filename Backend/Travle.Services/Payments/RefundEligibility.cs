using Travle.Services.Database;

namespace Travle.Services.Payments
{
    /// <summary>
    /// The one definition of "this captured charge is owed back to the traveler", and of which remedy pays
    /// it. The admin payments screen renders its Retry action from this and <c>RetryRefundAsync</c> enforces
    /// it, so the console can never offer a retry the API refuses — the same rule the August review asked
    /// for on schedule deletion, applied here.
    ///
    /// Two remedies exist because two different things can go wrong, and they answer "how much?" from
    /// different places:
    /// <list type="bullet">
    /// <item><b>A cancelled booking</b> owes the figure its cancelling transition froze onto it
    /// (<c>Booking.RefundPercentageOwed</c> / <c>RefundAmountOwed</c>). That is a settlement, and only the
    /// recorded amount may be paid.</item>
    /// <item><b>An orphaned charge</b> is money captured against a booking that was never honoured at all,
    /// so there is no cancellation and no recorded obligation — the whole charge goes back. The webhook
    /// creates this state when a payment lands too late (the booking is expired) or when the amount guard
    /// rejects it (the booking keeps its hold and the traveler retries with a correct charge).</item>
    /// </list>
    ///
    /// Both remedies run automatically first. This type exists for the case where that automatic attempt
    /// failed against Stripe: the money is still owed, <c>RefundService</c> raises a <c>RefundFailed</c>
    /// notification telling every admin to retry it from the payments screen, and that instruction has to
    /// lead somewhere.
    /// </summary>
    public static class RefundEligibility
    {
        /// <summary>How an owed refund is to be paid, or <see cref="None"/> when nothing is owed.</summary>
        public enum Remedy
        {
            /// <summary>Nothing owed: not captured, already refunded, or a live paid booking.</summary>
            None,

            /// <summary>Pay the obligation the booking recorded when it was cancelled.</summary>
            RecordedObligation,

            /// <summary>Refund the whole charge: it bought a booking that could not be honoured.</summary>
            OrphanedCharge
        }

        /// <summary>
        /// The remedy a payment needs, from the facts that decide it. Takes plain values rather than the
        /// entity so the admin list can call it over a projection, in memory, on exactly the columns it
        /// already reads.
        /// </summary>
        public static Remedy ResolveRemedy(
            int bookingStatusId,
            PaymentStatus paymentStatus,
            bool hasRefund,
            DateTime? paymentSucceededAt,
            DateTime? bookingCancelledAt)
        {
            // Only money actually taken can be given back, and never twice. A row that already carries a
            // Refund is settled whatever its booking says.
            if (paymentStatus != PaymentStatus.Succeeded || hasRefund)
            {
                return Remedy.None;
            }

            return (BookingStatusCode)bookingStatusId switch
            {
                // A cancelled booking normally owes the figure it recorded. But that figure was computed
                // from the charge captured *at the moment of cancellation*, so a charge that lands after it
                // was never part of that settlement — and the snapshot is very likely a zero, because at the
                // time nothing had been captured. That happens for real: an organizer retires a slot, or an
                // admin suspends them, while a traveler is mid-checkout, and the traveler's payment then
                // succeeds. Paying the snapshot there would hand back nothing for money genuinely taken, so
                // a late charge is an orphan like any other.
                //
                // Null-safe by construction: comparing a null DateTime? is false either way, so a row
                // missing either timestamp keeps the ordinary recorded-obligation answer.
                BookingStatusCode.Cancelled =>
                    paymentSucceededAt > bookingCancelledAt
                        ? Remedy.OrphanedCharge
                        : Remedy.RecordedObligation,

                // Expired: the hold lapsed or the tour departed before the charge landed, so the webhook
                // settled the booking and the seats went back.
                BookingStatusCode.Expired => Remedy.OrphanedCharge,

                // PaymentInProgress with a *captured* charge is not a booking mid-checkout — a payment that
                // succeeds normally promotes its booking to Pending. It is the amount-guard case: the charge
                // was banked, refused, and the hold deliberately left running so the traveler can pay again.
                BookingStatusCode.PaymentInProgress => Remedy.OrphanedCharge,

                // Pending / Confirmed / Completed are live paid bookings. The charge is doing its job.
                _ => Remedy.None
            };
        }
    }
}
