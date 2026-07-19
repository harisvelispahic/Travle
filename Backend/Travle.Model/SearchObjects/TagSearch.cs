namespace Travle.Model.SearchObjects
{
    public class TagSearch : BaseSearchObject
    {
        /// <summary>Filter by tag name (case-insensitive partial match).</summary>
        public string? Name { get; set; }
    }
}
