using System.ComponentModel.DataAnnotations;

namespace Travle.Services.BookingStateMachine
{
    /// <summary>
    /// Booking lifecycle settings, bound from the <c>Booking</c> configuration section. Currently just the
    /// platform-wide booking cutoff: how long before a departure a schedule stops accepting new bookings and
    /// completed payments. A tour may override it (<see cref="Database.Tour.BookingCutoffMinutes"/>); this
    /// is the value used when it doesn't.
    /// </summary>
    public sealed class BookingOptions
    {
        public const string SectionName = "Booking";

        /// <summary>
        /// Default minutes before a departure that booking and payment close, when the tour sets no override.
        /// Two hours: enough for the organizer to confirm or reject and for the traveler to hear back before
        /// they have to travel. 0 means "open until departure". See docs/tours-and-bookings.md.
        /// </summary>
        [Range(0, 10080)]
        public int DefaultCutoffMinutes { get; set; } = 120;
    }
}
