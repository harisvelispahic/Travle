namespace Travle.Services.Database
{
    /// <summary>
    /// A bookable tour offered by an organizer, visiting one or more destinations (ordered via
    /// <see cref="TourDestination"/>). "Deleting" a tour = deactivating it (<see cref="IsActive"/>);
    /// the refund policy is global, so there is no per-tour policy FK.
    /// </summary>
    public class Tour : BaseEntity
    {
        public int OrganizerId { get; set; }
        public User Organizer { get; set; } = null!;

        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;

        public int DurationMinutes { get; set; }
        public decimal PricePerPerson { get; set; }
        public int Capacity { get; set; }

        public int TourTypeId { get; set; }
        public TourType TourType { get; set; } = null!;

        public bool IsActive { get; set; } = true;

        public ICollection<TourSchedule> Schedules { get; set; } = new List<TourSchedule>();
        public ICollection<TourDestination> TourDestinations { get; set; } = new List<TourDestination>();
        public ICollection<TourReview> Reviews { get; set; } = new List<TourReview>();
    }
}
