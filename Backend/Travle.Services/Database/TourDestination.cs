namespace Travle.Services.Database
{
    /// <summary>
    /// Ordered m2m link between a <see cref="Tour"/> and the <see cref="Destination"/> stops it visits.
    /// Carries a meaningful attribute (<see cref="SortOrder"/>) so it inherits <see cref="BaseEntity"/>.
    /// </summary>
    public class TourDestination : BaseEntity
    {
        public int TourId { get; set; }
        public Tour Tour { get; set; } = null!;

        public int DestinationId { get; set; }
        public Destination Destination { get; set; } = null!;

        public int SortOrder { get; set; }
    }
}
