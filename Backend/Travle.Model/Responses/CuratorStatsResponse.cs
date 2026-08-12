namespace Travle.Model.Responses
{
    /// <summary>
    /// The curator statistics headline payload (stretch feature S3): the aggregate impact of the caller's
    /// submitted destinations — portfolio health, engagement (views / favorites / ratings) and the real
    /// demand they drive (bookings and travelers on tours that visit them). These are totals over <b>all</b>
    /// the curator's destinations; the per-destination breakdown is paginated separately via
    /// <c>GET /Reports/curator-stats/destinations</c>. Scoped server-side to the calling curator (id from
    /// the JWT, never the request). Curators earn no money, so there are no revenue figures here.
    /// </summary>
    public class CuratorStatsResponse
    {
        /// <summary>Total destinations the curator has ever submitted.</summary>
        public int TotalDestinations { get; set; }
        public int ApprovedDestinations { get; set; }
        public int PendingDestinations { get; set; }
        public int RejectedDestinations { get; set; }

        /// <summary>Combined view count across all the curator's destinations.</summary>
        public int TotalViews { get; set; }

        /// <summary>Number of times the curator's destinations have been favorited.</summary>
        public int TotalFavorites { get; set; }

        /// <summary>Average of non-removed destination-review ratings across all the curator's destinations.</summary>
        public double AverageRating { get; set; }
        public int ReviewCount { get; set; }

        /// <summary>Distinct bookings whose tour visits at least one of the curator's destinations.</summary>
        public int TotalBookings { get; set; }

        /// <summary>Travelers on those bookings (sum of party sizes).</summary>
        public int TotalTravelers { get; set; }
    }
}
