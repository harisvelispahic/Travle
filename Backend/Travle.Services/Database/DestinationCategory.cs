namespace Travle.Services.Database
{
    /// <summary>Reference table. Classifies destinations (Historical, Natural, Religious, …); a recommender feature.</summary>
    public class DestinationCategory : BaseEntity
    {
        public string Name { get; set; } = string.Empty;

        public ICollection<Destination> Destinations { get; set; } = new List<Destination>();
    }
}
