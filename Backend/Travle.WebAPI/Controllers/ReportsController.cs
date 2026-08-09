using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Reports;
using Travle.WebAPI.Authorization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

/// <summary>
/// The desktop reporting module (course §2.2/§2.4): the admin dashboard, the two downloadable/printable
/// PDF reports (each paired with a JSON preview endpoint feeding the on-screen table), and the
/// organizer statistics screen (§2.3). All aggregation and PDF composition happen in
/// <see cref="IReportService"/>; the controller only shapes the HTTP responses. Read-only — nothing here
/// mutates data.
/// </summary>
[ApiController]
[Route("[controller]")]
[Authorize(Policy = AuthPolicies.Authenticated)]
public class ReportsController : ControllerBase
{
    private readonly IReportService _service;

    public ReportsController(IReportService service)
    {
        _service = service;
    }

    /// <summary>Admin dashboard: metric tiles, bookings-per-month series and recent activity.</summary>
    [Authorize(Policy = AuthPolicies.AdminOnly)]
    [HttpGet("dashboard")]
    public async Task<ActionResult<DashboardResponse>> Dashboard(CancellationToken cancellationToken)
        => Ok(await _service.GetDashboardAsync(cancellationToken));

    /// <summary>Admin: "most popular destinations by period" data for the on-screen preview table.</summary>
    [Authorize(Policy = AuthPolicies.AdminOnly)]
    [HttpGet("popular-destinations")]
    public async Task<ActionResult<PopularDestinationsReport>> PopularDestinations(
        [FromQuery] PopularDestinationsReportSearch? search, CancellationToken cancellationToken)
        => Ok(await _service.GetPopularDestinationsAsync(
            search ?? new PopularDestinationsReportSearch(), cancellationToken));

    /// <summary>Admin: the popular-destinations report as a downloadable/printable PDF (same filter).</summary>
    [Authorize(Policy = AuthPolicies.AdminOnly)]
    [HttpGet("popular-destinations/pdf")]
    public async Task<IActionResult> PopularDestinationsPdf(
        [FromQuery] PopularDestinationsReportSearch? search, CancellationToken cancellationToken)
    {
        var pdf = await _service.GetPopularDestinationsPdfAsync(
            search ?? new PopularDestinationsReportSearch(), cancellationToken);
        return File(pdf, "application/pdf", "travle-popular-destinations.pdf");
    }

    /// <summary>Admin: "revenue by category / region" data for the on-screen preview tables.</summary>
    [Authorize(Policy = AuthPolicies.AdminOnly)]
    [HttpGet("revenue")]
    public async Task<ActionResult<RevenueReport>> Revenue(
        [FromQuery] RevenueReportSearch? search, CancellationToken cancellationToken)
        => Ok(await _service.GetRevenueReportAsync(search ?? new RevenueReportSearch(), cancellationToken));

    /// <summary>Admin: the revenue report as a downloadable/printable PDF (same filter).</summary>
    [Authorize(Policy = AuthPolicies.AdminOnly)]
    [HttpGet("revenue/pdf")]
    public async Task<IActionResult> RevenuePdf(
        [FromQuery] RevenueReportSearch? search, CancellationToken cancellationToken)
    {
        var pdf = await _service.GetRevenuePdfAsync(search ?? new RevenueReportSearch(), cancellationToken);
        return File(pdf, "application/pdf", "travle-revenue.pdf");
    }

    /// <summary>Organizer: statistics across the caller's own tours (scoped server-side to the JWT user).</summary>
    [Authorize(Policy = AuthPolicies.OrganizerOnly)]
    [HttpGet("organizer-stats")]
    public async Task<ActionResult<OrganizerStatsResponse>> OrganizerStats(CancellationToken cancellationToken)
        => Ok(await _service.GetOrganizerStatsAsync(cancellationToken));
}
