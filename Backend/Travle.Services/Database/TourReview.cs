namespace Travle.Services.Database
{
    /// <summary>
    /// A 1–5 rating + comment on a <see cref="Tour"/>, gated to the reviewer's own Completed
    /// <see cref="Booking"/> (unique per booking — no re-review after soft removal). Soft-removed via
    /// <see cref="IsRemoved"/> + audit.
    /// </summary>
    public class TourReview : BaseEntity
    {
        public int TourId { get; set; }
        public Tour Tour { get; set; } = null!;

        public int BookingId { get; set; }
        public Booking Booking { get; set; } = null!;

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
