namespace Travle.Model.SearchObjects
{
    /// <summary>
    /// Search + paging for the curator statistics per-destination breakdown
    /// (<c>GET /Reports/curator-stats/destinations</c>). Rows are always ordered by impact (bookings
    /// reached, then views, then name) server-side, so the client's infinite scroll gets a stable,
    /// meaningful sequence; <see cref="Name"/> narrows a large portfolio (course §2.2 — every list view
    /// carries at least one search parameter).
    /// </summary>
    public class CuratorDestinationsSearch : BaseSearchObject
    {
        /// <summary>Accent-aware "name contains" filter over the curator's own destinations.</summary>
        public string? Name { get; set; }
    }
}
