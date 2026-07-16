namespace Travle.Services.Database
{
    /// <summary>Reference table. A city belongs to a <see cref="Region"/> and locates a <see cref="Destination"/>.</summary>
    public class City : BaseEntity
    {
        public string Name { get; set; } = string.Empty;

        public int RegionId { get; set; }
        public Region Region { get; set; } = null!;

        public ICollection<Destination> Destinations { get; set; } = new List<Destination>();
    }
}
