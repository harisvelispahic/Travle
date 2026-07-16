namespace Travle.Services.Database
{
    /// <summary>
    /// Append-only recommender diary: one row per recorded signal (server-side only). Destination-linked
    /// rows carry <see cref="DestinationId"/>; onboarding rows carry <see cref="CategoryId"/>/<see cref="TagId"/>
    /// directly with a null destination; search rows store the matched category/tag alongside
    /// <see cref="SearchTerm"/> so the scorer maps searches to features without re-parsing text. Never
    /// updated or deleted — recommender integrity depends on it.
    /// </summary>
    public class UserInteraction : BaseEntity
    {
        public int UserId { get; set; }
        public User User { get; set; } = null!;

        public int? DestinationId { get; set; }
        public Destination? Destination { get; set; }

        public InteractionType InteractionType { get; set; }
        public double Weight { get; set; }

        public string? SearchTerm { get; set; }

        public int? CategoryId { get; set; }
        public DestinationCategory? Category { get; set; }

        public int? TagId { get; set; }
        public Tag? Tag { get; set; }
    }
}
