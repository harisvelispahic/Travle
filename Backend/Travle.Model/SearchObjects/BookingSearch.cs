namespace Travle.Model.SearchObjects
{
    /// <summary>
    /// Filters for the booking list endpoints. The traveler "my bookings" path scopes
    /// <see cref="UserId"/> to the JWT user server-side; the organizer "bookings on my tours" path scopes
    /// <see cref="OrganizerId"/> the same way — a caller can never widen either to someone else's data.
    /// Reference filters are FK ids, never strings.
    /// </summary>
    public class BookingSearch : BaseSearchObject
    {
        /// <summary>Filter by booking status (the seeded <c>BookingStatus</c> id).</summary>
        public int? StatusId { get; set; }

        /// <summary>Restrict to bookings placed by this traveler (used to scope "my bookings").</summary>
        public int? UserId { get; set; }

        /// <summary>Restrict to bookings on tours owned by this organizer (used to scope "my tours' bookings").</summary>
        public int? OrganizerId { get; set; }

        public int? TourId { get; set; }
        public int? TourScheduleId { get; set; }

        /// <summary>Only bookings whose schedule starts on/after this instant (UTC).</summary>
        public DateTime? FromDate { get; set; }

        /// <summary>Only bookings whose schedule starts before this instant (UTC).</summary>
        public DateTime? ToDate { get; set; }
    }
}
