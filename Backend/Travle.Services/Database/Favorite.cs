namespace Travle.Services.Database
{
    /// <summary>
    /// A user's favorite pointing at exactly one target — a <see cref="Destination"/> or a
    /// <see cref="Tour"/> (enforced by a check constraint; unique per user+target). Hard-deleted on
    /// toggle-off; the matching Favorite row in <see cref="UserInteraction"/> stays (append-only diary).
    /// </summary>
    public class Favorite : BaseEntity
    {
        public int UserId { get; set; }
        public User User { get; set; } = null!;

        public int? DestinationId { get; set; }
        public Destination? Destination { get; set; }

        public int? TourId { get; set; }
        public Tour? Tour { get; set; }
    }
}
