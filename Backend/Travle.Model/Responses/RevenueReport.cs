namespace Travle.Model.Responses
{
    /// <summary>
    /// The "revenue by category / region" report. Two single-GroupBy breakdowns of the same captured
    /// payments over the period — one keyed by the primary destination's category, one by its region —
    /// plus the reconciling grand totals. Used by both the JSON preview endpoint and the PDF endpoint.
    /// </summary>
    public class RevenueReport
    {
        public DateTime? FromDate { get; set; }
        public DateTime? ToDate { get; set; }

        public List<RevenueGroupRow> ByCategory { get; set; } = new();
        public List<RevenueGroupRow> ByRegion { get; set; } = new();

        public decimal TotalGross { get; set; }
        public decimal TotalRefunded { get; set; }
        public decimal TotalNet { get; set; }

        public string Currency { get; set; } = "bam";
    }
}
