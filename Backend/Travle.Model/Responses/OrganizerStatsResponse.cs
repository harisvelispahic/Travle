namespace Travle.Model.Responses
{
    /// <summary>
    /// The organizer statistics screen payload (course §2.3): headline counts, revenue and average
    /// rating across the organizer's own tours, the bookings-per-month series scoped to those tours, and
    /// a per-tour breakdown. Scoped server-side to the calling organizer (id from the JWT, never the
    /// request). <see cref="PlatformCommission"/> is bookkeeping only — organizers are never paid out.
    /// </summary>
    public class OrganizerStatsResponse
    {
        public int TotalBookings { get; set; }
        public int PendingBookings { get; set; }
        public int ConfirmedBookings { get; set; }
        public int CompletedBookings { get; set; }
        public int CancelledBookings { get; set; }

        /// <summary>Gross captured across the organizer's tours (before refunds).</summary>
        public decimal GrossRevenue { get; set; }

        /// <summary>Total refunded to travelers across the organizer's tours.</summary>
        public decimal TotalRefunded { get; set; }

        /// <summary>Platform commission on the retained funds (bookkeeping only).</summary>
        public decimal PlatformCommission { get; set; }

        /// <summary>
        /// The organizer's net earnings — gross minus refunds minus platform commission (i.e. their share
        /// of the retained revenue). Notional only: organizers are never actually paid out.
        /// </summary>
        public decimal NetEarnings { get; set; }

        /// <summary>Average of non-removed tour-review ratings across all the organizer's tours.</summary>
        public double AverageRating { get; set; }
        public int ReviewCount { get; set; }

        public string Currency { get; set; } = "bam";

        public List<MonthlyBookingPoint> BookingsPerMonth { get; set; } = new();
        public List<OrganizerTourStatRow> Tours { get; set; } = new();
    }
}
