namespace Travle.Model.SearchObjects
{
    public class CitySearch : BaseSearchObject
    {
        /// <summary>Filter by city name (case-insensitive partial match).</summary>
        public string? Name { get; set; }

        /// <summary>Filter cities belonging to a specific region (drives the Region → City chaining).</summary>
        public int? RegionId { get; set; }
    }
}
