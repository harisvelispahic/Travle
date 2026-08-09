namespace Travle.Model.SearchObjects
{
    /// <summary>
    /// Parameters for the "revenue by category / region" report — shared by the JSON preview and the PDF
    /// endpoint. The optional date range (UTC) is matched on the payment's creation instant; omitting
    /// both bounds reports over all time.
    /// </summary>
    public class RevenueReportSearch
    {
        public DateTime? FromDate { get; set; }
        public DateTime? ToDate { get; set; }
    }
}
