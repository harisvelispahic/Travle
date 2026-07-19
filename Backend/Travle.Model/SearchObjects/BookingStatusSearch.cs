namespace Travle.Model.SearchObjects
{
    public class BookingStatusSearch : BaseSearchObject
    {
        /// <summary>Filter by status name (case-insensitive partial match).</summary>
        public string? Name { get; set; }
    }
}
