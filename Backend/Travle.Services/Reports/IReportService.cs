using Travle.Model.Responses;
using Travle.Model.SearchObjects;

namespace Travle.Services.Reports
{
    /// <summary>
    /// Read-only reporting aggregates for the desktop administrative module (course §2.2/§2.4) and the
    /// organizer statistics screen (§2.3). Every figure is computed with DB-level aggregates; nothing
    /// here mutates data. Admin methods are guarded for <c>Admin</c>; the organizer method is scoped to
    /// the calling organizer (id from the JWT). The two report DTOs are also fed to the PDF documents.
    /// </summary>
    public interface IReportService
    {
        /// <summary>Admin dashboard metrics, the bookings-per-month series and the recent-activity feed.</summary>
        Task<DashboardResponse> GetDashboardAsync(CancellationToken cancellationToken = default);

        /// <summary>"Most popular destinations by period" report data (ranked by bookings in the period).</summary>
        Task<PopularDestinationsReport> GetPopularDestinationsAsync(
            PopularDestinationsReportSearch search, CancellationToken cancellationToken = default);

        /// <summary>"Revenue by category / region" report data (attributed to the tour's primary destination).</summary>
        Task<RevenueReport> GetRevenueReportAsync(
            RevenueReportSearch search, CancellationToken cancellationToken = default);

        /// <summary>The popular-destinations report rendered as a downloadable/printable PDF (same data).</summary>
        Task<byte[]> GetPopularDestinationsPdfAsync(
            PopularDestinationsReportSearch search, CancellationToken cancellationToken = default);

        /// <summary>The revenue report rendered as a downloadable/printable PDF (same data).</summary>
        Task<byte[]> GetRevenuePdfAsync(
            RevenueReportSearch search, CancellationToken cancellationToken = default);

        /// <summary>Statistics across the calling organizer's own tours (bookings, revenue, average rating).</summary>
        Task<OrganizerStatsResponse> GetOrganizerStatsAsync(CancellationToken cancellationToken = default);
    }
}
