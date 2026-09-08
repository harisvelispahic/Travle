namespace Travle.Model.Requests
{
    /// <summary>
    /// An organizer's new tour. The organizer is taken from the JWT (never the client). Tour type is an
    /// FK id resolved server-side. <see cref="DestinationIds"/> is the ordered itinerary — the list
    /// order becomes each stop's <c>SortOrder</c> — and every id must reference an approved destination
    /// (verified in the service, since it needs the database).
    /// </summary>
    public class TourInsertRequest
    {
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;

        public int DurationMinutes { get; set; }
        public decimal PricePerPerson { get; set; }

        /// <summary>Default group size seeded into new schedules.</summary>
        public int Capacity { get; set; }

        public int TourTypeId { get; set; }

        /// <summary>
        /// Minutes before a departure that bookings and payments close for this tour — the organizer's lead
        /// time to confirm or reject. Null uses the platform default; 0 keeps a departure bookable until it
        /// starts.
        /// </summary>
        public int? BookingCutoffMinutes { get; set; }

        /// <summary>Approved destinations to visit, in itinerary order (order = SortOrder). At least one.</summary>
        public List<int> DestinationIds { get; set; } = new List<int>();
    }
}
