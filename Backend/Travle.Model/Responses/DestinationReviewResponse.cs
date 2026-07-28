namespace Travle.Model.Responses
{
    /// <summary>
    /// A rating + comment left on a destination, in the shape used by the reviews list, the author's own
    /// review, and the admin moderation table. The destination and both user references are flattened to
    /// names (never raw ids on screen). Removed reviews are excluded from public reads and rating
    /// aggregates; the moderation view opts them in and reads the removal audit.
    /// </summary>
    public class DestinationReviewResponse
    {
        public int Id { get; set; }

        public int DestinationId { get; set; }
        public string DestinationName { get; set; } = string.Empty;

        public int UserId { get; set; }
        public string Username { get; set; } = string.Empty;
        public string AuthorName { get; set; } = string.Empty;

        public int Rating { get; set; }
        public string? Comment { get; set; }

        public bool IsRemoved { get; set; }
        public int? RemovedByUserId { get; set; }
        public string? RemovedByUsername { get; set; }
        public string? RemovalReason { get; set; }

        public DateTime CreatedAt { get; set; }
        public DateTime? ModifiedAt { get; set; }
    }
}
