namespace Travle.Model.SearchObjects
{
    public class TourTypeSearch : BaseSearchObject
    {
        /// <summary>Filter by tour type name (case-insensitive partial match).</summary>
        public string? Name { get; set; }
    }
}
