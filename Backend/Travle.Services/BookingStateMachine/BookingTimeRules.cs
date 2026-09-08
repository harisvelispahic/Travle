using Travle.Model.Exceptions;

namespace Travle.Services.BookingStateMachine
{
    /// <summary>
    /// The one place the booking lifecycle's time rules live, so creation, the payment hold, the Stripe
    /// webhook, every organizer/traveler transition and the capability flags the clients render can never
    /// disagree about what "too late" means.
    ///
    /// Two deadlines, both relative to <c>TourSchedule.StartsAt</c>:
    /// <list type="bullet">
    /// <item><b>The booking cutoff</b> (<see cref="BookingClosesAt"/>) — the tour's own
    /// <c>BookingCutoffMinutes</c> or the platform default. New bookings are refused from here on and a
    /// payment hold can never outlive it, so a booking that reaches Pending always leaves the organizer
    /// real time to confirm or reject before the traveler has to set off.</item>
    /// <item><b>The departure itself</b> (<see cref="HasStarted"/>) — the hard wall for the discretionary
    /// transitions. Once a tour has started, confirming, rejecting or cancelling a booking would rewrite
    /// the history of something that already happened, so all four are refused.</item>
    /// </list>
    /// </summary>
    public static class BookingTimeRules
    {
        /// <summary>
        /// Grace beyond a hold's expiry, shared by the lifecycle sweep (which won't expire a booking until
        /// it is this far overdue) and the Stripe webhook (which will still honour a charge that lands this
        /// soon after). A payment confirmed in the final seconds of a hold must not race the sweep and
        /// strand a real charge, so both sides read the same number.
        /// </summary>
        public static readonly TimeSpan HoldGracePeriod = TimeSpan.FromSeconds(90);

        /// <summary>
        /// Whether a hold is still worth honouring at <paramref name="now"/>, grace included. A booking with
        /// no expiry (already promoted past the payment stage) is never "lapsed" by this rule.
        /// </summary>
        public static bool IsHoldHonoured(DateTime? expiresAt, DateTime now)
            => expiresAt is not DateTime expiry || now <= expiry.Add(HoldGracePeriod);

        /// <summary>The tour's own cutoff when it sets one, otherwise the configured platform default.</summary>
        public static int ResolveCutoffMinutes(int? tourCutoffMinutes, BookingOptions options)
            => tourCutoffMinutes ?? options.DefaultCutoffMinutes;

        /// <summary>The instant a schedule stops accepting new bookings and completed payments.</summary>
        public static DateTime BookingClosesAt(DateTime startsAt, int cutoffMinutes)
            => startsAt.AddMinutes(-cutoffMinutes);

        /// <summary>Whether a schedule is still open for a new booking at <paramref name="now"/>.</summary>
        public static bool IsOpenForBooking(DateTime startsAt, int cutoffMinutes, DateTime now)
            => now < BookingClosesAt(startsAt, cutoffMinutes);

        /// <summary>Whether the departure itself has come and gone.</summary>
        public static bool HasStarted(DateTime startsAt, DateTime now) => startsAt <= now;

        /// <summary>
        /// Refuses a new booking once the cutoff has passed. The message names the cutoff so a traveler who
        /// hits it understands the rule rather than just being told no.
        /// </summary>
        public static void EnsureOpenForBooking(DateTime startsAt, int cutoffMinutes, DateTime now)
        {
            if (IsOpenForBooking(startsAt, cutoffMinutes, now))
            {
                return;
            }

            throw new BusinessRuleException(HasStarted(startsAt, now)
                ? "This departure has already started and can no longer be booked."
                : $"Bookings for this departure closed {DescribeCutoff(cutoffMinutes)} before it starts.");
        }

        /// <summary>
        /// Refuses a new schedule that would be born unbookable — one starting so soon that its own booking
        /// cutoff has already passed. Creation is the organizer's side of the same rule travelers meet in
        /// <see cref="EnsureOpenForBooking"/>: publishing a date nobody could ever book is a mistake worth
        /// catching at the point it is made, not one to discover from an empty departures list.
        /// </summary>
        public static void EnsureSchedulable(DateTime startsAt, int cutoffMinutes, DateTime now)
        {
            if (IsOpenForBooking(startsAt, cutoffMinutes, now))
            {
                return;
            }

            if (cutoffMinutes == 0)
            {
                throw new BusinessRuleException("A schedule must start in the future.");
            }

            throw new BusinessRuleException(
                $"This tour closes bookings {DescribeCutoff(cutoffMinutes)} before departure, so a date starting "
                + $"that soon could never be booked. Pick a start at least {DescribeCutoff(cutoffMinutes)} from now, "
                + "or lower the tour's booking cutoff.");
        }

        /// <summary>
        /// Refuses a discretionary transition (confirm / reject / cancel) on a departure that has already
        /// started. <paramref name="pastTenseAction"/> completes "cannot be …".
        /// </summary>
        public static void EnsureNotStarted(DateTime startsAt, DateTime now, string pastTenseAction)
        {
            if (!HasStarted(startsAt, now))
            {
                return;
            }

            throw new BusinessRuleException(
                $"This booking cannot be {pastTenseAction}: its tour has already started.");
        }

        /// <summary>
        /// How long a new booking may hold its seats: the standard hold, cut short so it can never outlive
        /// the cutoff. Creation is refused before the cutoff (see <see cref="EnsureOpenForBooking"/>), so the
        /// result is always in the future.
        /// </summary>
        public static DateTime HoldExpiryFor(DateTime startsAt, int cutoffMinutes, DateTime now, TimeSpan holdDuration)
        {
            var standardExpiry = now.Add(holdDuration);
            var closesAt = BookingClosesAt(startsAt, cutoffMinutes);
            return standardExpiry < closesAt ? standardExpiry : closesAt;
        }

        // "2 hours" / "90 minutes" / "1 hour" — the cutoff as a traveler would say it.
        private static string DescribeCutoff(int cutoffMinutes)
        {
            if (cutoffMinutes % 60 != 0)
            {
                return $"{cutoffMinutes} minutes";
            }

            var hours = cutoffMinutes / 60;
            return hours == 1 ? "1 hour" : $"{hours} hours";
        }
    }
}
