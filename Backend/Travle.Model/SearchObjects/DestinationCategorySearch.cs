namespace Travle.Model.SearchObjects
{
    public class DestinationCategorySearch : BaseSearchObject
    {
        /// <summary>Filter by category name (case-insensitive partial match).</summary>
        public string? Name { get; set; }
    }
}
