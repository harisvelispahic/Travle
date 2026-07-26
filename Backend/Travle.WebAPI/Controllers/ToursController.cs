using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services;
using Travle.WebAPI.Authorization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

/// <summary>
/// Tours and their schedule slots. Any authenticated user may browse active tours (<c>GetAll</c> = public
/// search), open a tour's detail, and list its upcoming slots; organizers create and manage their own
/// (<c>Create</c> / <c>Update</c> / <c>Delete</c> / <c>mine</c> / (de)activate and the schedule verbs,
/// ownership enforced in the service). The visited destinations' full image bytes come from the
/// destination image endpoint, so tour payloads stay light.
/// </summary>
[Authorize(Policy = AuthPolicies.Authenticated)]
public class ToursController
    : BaseCRUDController<TourResponse, TourSearch, TourInsertRequest, TourUpdateRequest, ITourService>
{
    public ToursController(ITourService service) : base(service)
    {
    }

    // Public browse: active tours only (enforced in the service).
    public override async Task<PageResult<TourResponse>> GetAll([FromQuery] TourSearch? search)
        => await _service.SearchAsync(search);

    // Detail read (ordered stops + upcoming slots). An inactive tour is visible only to its organizer/admin.
    public override async Task<ActionResult<TourResponse>> GetById(int id)
        => Ok(await _service.GetDetailAsync(id));

    // The current organizer's own tours, active or not.
    [Authorize(Policy = AuthPolicies.OrganizerOnly)]
    [HttpGet("mine")]
    public async Task<ActionResult<PageResult<TourResponse>>> GetMine([FromQuery] TourSearch? search)
        => Ok(await _service.GetMineAsync(search));

    [Authorize(Policy = AuthPolicies.OrganizerOnly)]
    [HttpPost]
    public override Task<ActionResult<TourResponse>> Create([FromBody] TourInsertRequest request)
        => base.Create(request);

    [Authorize(Policy = AuthPolicies.OrganizerOnly)]
    [HttpPut("{id}")]
    public override Task<ActionResult<TourResponse>> Update(int id, [FromBody] TourUpdateRequest request)
        => base.Update(id, request);

    [Authorize(Policy = AuthPolicies.OrganizerOnly)]
    [HttpDelete("{id}")]
    public override Task<IActionResult> Delete(int id)
        => base.Delete(id);

    [Authorize(Policy = AuthPolicies.OrganizerOnly)]
    [HttpPost("{id}/Deactivate")]
    public async Task<ActionResult<TourResponse>> Deactivate(int id)
        => Ok(await _service.DeactivateAsync(id));

    [Authorize(Policy = AuthPolicies.OrganizerOnly)]
    [HttpPost("{id}/Activate")]
    public async Task<ActionResult<TourResponse>> Activate(int id)
        => Ok(await _service.ActivateAsync(id));

    // A tour's schedule slots. Non-owners are narrowed to bookable (Active, future) slots in the service.
    [HttpGet("{tourId}/Schedules")]
    public async Task<ActionResult<PageResult<TourScheduleResponse>>> GetSchedules(int tourId, [FromQuery] TourScheduleSearch? search)
        => Ok(await _service.GetSchedulesAsync(tourId, search));

    [Authorize(Policy = AuthPolicies.OrganizerOnly)]
    [HttpPost("{tourId}/Schedules")]
    public async Task<ActionResult<TourScheduleResponse>> AddSchedule(int tourId, [FromBody] TourScheduleInsertRequest request)
        => StatusCode(StatusCodes.Status201Created, await _service.AddScheduleAsync(tourId, request));

    [Authorize(Policy = AuthPolicies.OrganizerOnly)]
    [HttpPost("Schedules/{scheduleId}/Cancel")]
    public async Task<ActionResult<TourScheduleResponse>> CancelSchedule(int scheduleId, [FromBody] TourScheduleCancelRequest request)
        => Ok(await _service.CancelScheduleAsync(scheduleId, request));

    [Authorize(Policy = AuthPolicies.OrganizerOnly)]
    [HttpDelete("Schedules/{scheduleId}")]
    public async Task<IActionResult> DeleteSchedule(int scheduleId)
    {
        await _service.DeleteScheduleAsync(scheduleId);
        return NoContent();
    }
}
