namespace Travle.Model.Requests
{
    /// <summary>
    /// A registered user's new review of an approved destination. The author is taken from the JWT (never
    /// trusted from the client); one active review per user per destination is enforced in the service.
    /// </summary>
    public class DestinationReviewInsertRequest
    {
        public int DestinationId { get; set; }

        /// <summary>1–5 stars.</summary>
        public int Rating { get; set; }

        public string? Comment { get; set; }
    }
}
