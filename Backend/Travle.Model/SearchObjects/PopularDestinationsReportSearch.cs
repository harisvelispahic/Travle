namespace Travle.Model.SearchObjects
{
    /// <summary>
    /// Parameters for the "most popular destinations by period" report — shared by the JSON preview and
    /// the PDF endpoint. The date range (UTC) is matched on the booking's creation instant;
    /// <see cref="CategoryId"/> optionally narrows to one category; <see cref="Top"/> caps the ranked
    /// rows (defaults to 10, hard-capped in the service).
    /// </summary>
    public class PopularDestinationsReportSearch
    {
        public DateTime? FromDate { get; set; }
        public DateTime? ToDate { get; set; }
        public int? CategoryId { get; set; }
        public int? Top { get; set; }
    }
}
