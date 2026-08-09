namespace Travle.Model.Responses
{
    /// <summary>
    /// The "most popular destinations by period" report: the ranked rows plus the period they were
    /// computed over (echoed back so the PDF header and the on-screen table agree). Used by both the
    /// JSON preview endpoint and the PDF endpoint.
    /// </summary>
    public class PopularDestinationsReport
    {
        public DateTime? FromDate { get; set; }
        public DateTime? ToDate { get; set; }

        /// <summary>Optional category the report was filtered to (null = all categories).</summary>
        public string? CategoryName { get; set; }

        public List<PopularDestinationRow> Rows { get; set; } = new();
    }
}
