namespace Travle.Model.Requests
{
    /// <summary>
    /// An author's edit of their own tour review. Only the rating and comment can change; the target
    /// booking/tour is fixed.
    /// </summary>
    public class TourReviewUpdateRequest
    {
        /// <summary>1–5 stars.</summary>
        public int Rating { get; set; }

        public string? Comment { get; set; }
    }
}
