namespace Travle.Model.Requests
{
    /// <summary>
    /// An author's edit of their own destination review. Only the rating and comment can change; the
    /// target destination is fixed.
    /// </summary>
    public class DestinationReviewUpdateRequest
    {
        /// <summary>1–5 stars.</summary>
        public int Rating { get; set; }

        public string? Comment { get; set; }
    }
}
