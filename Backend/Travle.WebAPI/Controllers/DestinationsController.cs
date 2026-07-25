using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services;
using Travle.WebAPI.Authorization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

/// <summary>
/// Tourist destinations. Any authenticated user may browse the approved catalogue (<c>GetAll</c> = public
/// search) and a destination's detail; curators/organizers submit and manage their own (<c>Create</c> /
/// <c>Update</c> / <c>Delete</c> / <c>mine</c>, enforced in the service); admins moderate
/// (<c>moderation</c> / Approve / Reject / Featured). Full image bytes come from the image endpoint so
/// list/detail payloads stay light.
/// </summary>
[Authorize(Policy = AuthPolicies.Authenticated)]
public class DestinationsController
    : BaseCRUDController<DestinationResponse, DestinationSearch, DestinationInsertRequest, DestinationUpdateRequest, IDestinationService>
{
    public DestinationsController(IDestinationService service) : base(service)
    {
    }

    // Public catalogue: approved-only, and a text term logs a Search interaction (enforced in the service).
    public override async Task<PageResult<DestinationResponse>> GetAll([FromQuery] DestinationSearch? search)
        => await _service.SearchAsync(search);

    // Detail read; logs a View (+ViewCount) for an approved destination viewed by someone other than its
    // submitter. Same return type as the inherited GetById, so it stays on the {id} route.
    public override async Task<ActionResult<DestinationResponse>> GetById(int id)
        => Ok(await _service.GetDetailAsync(id));

    // The current curator/organizer's own submissions, any status.
    [HttpGet("mine")]
    public async Task<ActionResult<PageResult<DestinationResponse>>> GetMine([FromQuery] DestinationSearch? search)
        => Ok(await _service.GetMineAsync(search));

    // Admin moderation queue (defaults to Pending; ?status=1/2 to review approved/rejected).
    [Authorize(Policy = AuthPolicies.AdminOnly)]
    [HttpGet("moderation")]
    public async Task<ActionResult<PageResult<DestinationResponse>>> Moderation([FromQuery] DestinationSearch? search)
        => Ok(await _service.GetModerationQueueAsync(search));

    [Authorize(Policy = AuthPolicies.AdminOnly)]
    [HttpPost("{id}/Approve")]
    public async Task<ActionResult<DestinationResponse>> Approve(int id)
        => Ok(await _service.ApproveAsync(id));

    [Authorize(Policy = AuthPolicies.AdminOnly)]
    [HttpPost("{id}/Reject")]
    public async Task<ActionResult<DestinationResponse>> Reject(int id, [FromBody] DestinationRejectRequest request)
        => Ok(await _service.RejectAsync(id, request));

    [Authorize(Policy = AuthPolicies.AdminOnly)]
    [HttpPost("{id}/Featured")]
    public async Task<ActionResult<DestinationResponse>> SetFeatured(int id, [FromBody] DestinationFeatureRequest request)
        => Ok(await _service.SetFeaturedAsync(id, request.IsFeatured));

    // Full image bytes. Approved images are readable by any authenticated user; unpublished ones only by
    // the submitter or an admin (enforced in the service). A missing image throws NotFoundException in the
    // service, which the exception pipeline turns into a 404 — the controller stays free of that check.
    [HttpGet("{id}/images/{imageId}")]
    public async Task<IActionResult> GetImage(int id, int imageId)
    {
        var image = await _service.GetImageAsync(id, imageId);
        return File(image.Content, image.ContentType);
    }
}
