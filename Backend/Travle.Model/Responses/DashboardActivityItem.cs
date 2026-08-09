namespace Travle.Model.Responses
{
    /// <summary>
    /// One row of the admin dashboard's "recent activity" feed — a merged, most-recent-first list of
    /// platform events (new bookings, role applications, submitted destinations). Names only, never raw
    /// IDs (course §K). <see cref="Kind"/> is a stable discriminator the UI maps to an icon.
    /// </summary>
    public class DashboardActivityItem
    {
        /// <summary>Event category: "Booking", "RoleApplication" or "Destination".</summary>
        public string Kind { get; set; } = string.Empty;

        /// <summary>Short headline, e.g. "New booking".</summary>
        public string Title { get; set; } = string.Empty;

        /// <summary>Human-readable detail, e.g. "Mirza Traveler booked 'Mostar Old Town Walking Tour'".</summary>
        public string Description { get; set; } = string.Empty;

        /// <summary>When the event happened (UTC).</summary>
        public DateTime Timestamp { get; set; }
    }
}
