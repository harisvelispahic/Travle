namespace Travle.Services.Database
{
    /// <summary>
    /// A tourist destination submitted by a curator/organizer and moderated by an admin. Any edit
    /// sends it back to <see cref="DestinationStatus.Pending"/> (enforced in the service).
    /// <see cref="AverageRating"/> and <see cref="ViewCount"/> are denormalized, maintained
    /// transactionally, and consumed by the UI and the recommender's popularity term.
    /// </summary>
    public class Destination : BaseEntity
    {
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;

        public int CategoryId { get; set; }
        public DestinationCategory Category { get; set; } = null!;

        public int CityId { get; set; }
        public City City { get; set; } = null!;

        public double Latitude { get; set; }
        public double Longitude { get; set; }

        public int SubmittedByUserId { get; set; }
        public User SubmittedByUser { get; set; } = null!;

        public DestinationStatus Status { get; set; } = DestinationStatus.Pending;

        public int? ModeratedByUserId { get; set; }
        public User? ModeratedByUser { get; set; }
        public DateTime? ModeratedAt { get; set; }
        public string? RejectionReason { get; set; }

        public bool IsFeatured { get; set; }

        public double AverageRating { get; set; }
        public int ViewCount { get; set; }

        public ICollection<DestinationImage> Images { get; set; } = new List<DestinationImage>();
        public ICollection<DestinationTag> DestinationTags { get; set; } = new List<DestinationTag>();
        public ICollection<DestinationReview> Reviews { get; set; } = new List<DestinationReview>();
        public ICollection<TourDestination> TourDestinations { get; set; } = new List<TourDestination>();
    }
}
