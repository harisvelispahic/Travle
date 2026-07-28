namespace Travle.Model.Requests
{
    /// <summary>
    /// A traveler's review of a tour, keyed by their own <see cref="BookingId"/>. The tour is derived from
    /// the booking; the service verifies the booking belongs to the JWT user and is Completed, and that
    /// the booking has not already been reviewed (unique per booking).
    /// </summary>
    public class TourReviewInsertRequest
    {
        public int BookingId { get; set; }

        /// <summary>1–5 stars.</summary>
        public int Rating { get; set; }

        public string? Comment { get; set; }
    }
}
