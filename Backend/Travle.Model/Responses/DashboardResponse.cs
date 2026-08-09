namespace Travle.Model.Responses
{
    /// <summary>
    /// The admin dashboard payload (course §2.4): headline metric tiles, the bookings-per-month chart
    /// series, and the recent-activity feed. All figures are computed server-side with DB-level
    /// aggregates over the whole platform. Money is in <see cref="Currency"/> minor-of-none decimals
    /// (KM), matching the payments screen.
    /// </summary>
    public class DashboardResponse
    {
        /// <summary>Total registered user accounts.</summary>
        public int TotalUsers { get; set; }

        /// <summary>
        /// Active tours: <c>IsActive</c>, owned by a non-suspended organizer, with at least one future
        /// non-cancelled schedule.
        /// </summary>
        public int ActiveTours { get; set; }

        /// <summary>Role applications still awaiting an admin decision.</summary>
        public int PendingRoleApplications { get; set; }

        /// <summary>Destinations awaiting moderation.</summary>
        public int PendingDestinations { get; set; }

        /// <summary>Net revenue captured in the current calendar month (gross captured − refunds issued).</summary>
        public decimal MonthlyNetRevenue { get; set; }

        public string Currency { get; set; } = "bam";

        /// <summary>Bookings per month for the trailing 12 months (oldest first, no gaps).</summary>
        public List<MonthlyBookingPoint> BookingsPerMonth { get; set; } = new();

        /// <summary>Most-recent platform events, newest first.</summary>
        public List<DashboardActivityItem> RecentActivity { get; set; } = new();
    }
}
