namespace Travle.Model.SearchObjects
{
    /// <summary>
    /// Paging parameters for the curator statistics per-destination breakdown
    /// (<c>GET /Reports/curator-stats/destinations</c>). Only the <see cref="BaseSearchObject"/> paging
    /// fields apply — the rows are always ordered by impact (bookings reached, then views, then name)
    /// server-side, so the client's infinite scroll gets a stable, meaningful sequence.
    /// </summary>
    public class CuratorDestinationsSearch : BaseSearchObject
    {
    }
}
