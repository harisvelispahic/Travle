namespace Travle.Model.SearchObjects
{
    public class CountrySearch : BaseSearchObject
    {
        /// <summary>Filter by country name (case-insensitive partial match).</summary>
        public string? Name { get; set; }
    }
}
