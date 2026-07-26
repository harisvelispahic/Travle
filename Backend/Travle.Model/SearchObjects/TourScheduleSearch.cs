namespace Travle.Model.SearchObjects
{
    /// <summary>
    /// Filters for a tour's schedule list (the organizer slot manager). Non-owners are transparently
    /// narrowed to Active, future slots in the service regardless of these values; the owner/admin may
    /// use them to review past or cancelled slots too.
    /// </summary>
    public class TourScheduleSearch : BaseSearchObject
    {
        /// <summary>Keep only slots starting at or after this instant (UTC).</summary>
        public DateTime? FromDate { get; set; }

        /// <summary>Keep only slots starting before this instant (UTC).</summary>
        public DateTime? ToDate { get; set; }

        /// <summary>When true, exclude Cancelled slots.</summary>
        public bool? ActiveOnly { get; set; }

        /// <summary>When true, keep only slots that still have at least one free seat.</summary>
        public bool? HasFreeSeats { get; set; }
    }
}
