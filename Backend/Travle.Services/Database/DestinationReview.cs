namespace Travle.Services.Database
{
    /// <summary>
    /// A 1–5 rating + comment left on a <see cref="Destination"/> by a registered user. Soft-removed
    /// by admin moderation (<see cref="IsRemoved"/> + who/when/reason); rating aggregates recompute
    /// excluding removed rows.
    /// </summary>
    public class DestinationReview : BaseEntity
    {
        public int DestinationId { get; set; }
        public Destination Destination { get; set; } = null!;

        public int UserId { get; set; }
        public User User { get; set; } = null!;

        public int Rating { get; set; }
        public string? Comment { get; set; }

        public bool IsRemoved { get; set; }
        public int? RemovedByUserId { get; set; }
        public User? RemovedByUser { get; set; }
        public string? RemovalReason { get; set; }
    }
}
