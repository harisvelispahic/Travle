namespace Travle.Services.Database
{
    /// <summary>Reference table. Classifies tours (Walking, Cultural, Adventure, …).</summary>
    public class TourType : BaseEntity
    {
        public string Name { get; set; } = string.Empty;

        public ICollection<Tour> Tours { get; set; } = new List<Tour>();
    }
}
