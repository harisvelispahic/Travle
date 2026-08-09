namespace Travle.Model.Responses
{
    /// <summary>
    /// One aggregated row of the revenue report — a single category or region. Revenue is attributed to
    /// the tour's <b>primary</b> (first-ordered) destination, so the rows sum exactly to the overall
    /// totals. <see cref="NetRevenue"/> = <see cref="GrossRevenue"/> − <see cref="Refunded"/>.
    /// </summary>
    public class RevenueGroupRow
    {
        public string GroupName { get; set; } = string.Empty;
        public int Bookings { get; set; }
        public decimal GrossRevenue { get; set; }
        public decimal Refunded { get; set; }
        public decimal NetRevenue { get; set; }
    }
}
