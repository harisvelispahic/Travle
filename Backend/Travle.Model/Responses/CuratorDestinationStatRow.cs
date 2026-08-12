namespace Travle.Model.Responses
{
    /// <summary>
    /// Per-destination line of the curator statistics screen: how each of the curator's own submissions is
    /// performing. Engagement figures (<see cref="Views"/>, <see cref="Favorites"/>, <see cref="AverageRating"/>)
    /// apply to any status; <see cref="Bookings"/>/<see cref="Travelers"/> count the demand on tours that visit
    /// this destination (0 for a submission not yet on any booked tour). <see cref="AverageRating"/> is 0 when
    /// the destination has no (non-removed) reviews yet.
    /// </summary>
    public class CuratorDestinationStatRow
    {
        public string DestinationName { get; set; } = string.Empty;

        /// <summary>Moderation status name ("Pending" / "Approved" / "Rejected").</summary>
        public string Status { get; set; } = string.Empty;

        public int Views { get; set; }
        public int Favorites { get; set; }
        public double AverageRating { get; set; }
        public int ReviewCount { get; set; }

        /// <summary>Bookings on tours that visit this destination (this row only; may overlap other rows).</summary>
        public int Bookings { get; set; }

        /// <summary>Travelers on those bookings (sum of party sizes).</summary>
        public int Travelers { get; set; }
    }
}
