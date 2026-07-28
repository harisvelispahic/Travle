namespace Travle.Model.Responses
{
    /// <summary>
    /// A rating + comment on a tour, gated to the reviewer's own Completed booking. Used by the tour's
    /// reviews list, the organizer's "reviews of my tours" view, and the admin moderation table. Tour and
    /// user references are flattened to names. Removed reviews are excluded from public reads and
    /// aggregates; the moderation view opts them in and reads the removal audit. <see cref="BookingId"/>
    /// stays occupied after removal (no re-review — 03 §3).
    /// </summary>
    public class TourReviewResponse
    {
        public int Id { get; set; }

        public int TourId { get; set; }
        public string TourName { get; set; } = string.Empty;

        public int BookingId { get; set; }

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
