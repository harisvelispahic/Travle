namespace Travle.Model.SearchObjects
{
    public class RegionSearch : BaseSearchObject
    {
        /// <summary>Filter by region name (case-insensitive partial match).</summary>
        public string? Name { get; set; }

        /// <summary>Filter regions belonging to a specific country (drives the Country → Region chaining).</summary>
        public int? CountryId { get; set; }
    }
}
