using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services;
using Travle.WebAPI.Authorization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

/// <summary>
/// Destination reviews. Any authenticated user may read a destination's reviews and post/edit/remove their
/// own; admins moderate (remove with a reason). Gating (approved target, one active review per user,
/// author-only edits, admin-only moderation removal) and the average-rating recompute live in the service.
/// </summary>
[ApiController]
[Route("[controller]")]
[Authorize(Policy = AuthPolicies.Authenticated)]
public class DestinationReviewsController : ControllerBase
{
    private readonly IDestinationReviewService _service;

    public DestinationReviewsController(IDestinationReviewService service)
    {
        _service = service;
    }

    /// <summary>A destination's reviews (filter by destination/user/rating), paginated. Removed rows are
    /// admin-only (via <c>includeRemoved</c>); everyone else sees active reviews only.</summary>
    [HttpGet]
    public async Task<ActionResult<PageResult<DestinationReviewResponse>>> GetAll([FromQuery] DestinationReviewSearch? search)
        => Ok(await _service.GetAllAsync(search));

    [HttpGet("{id}")]
    public async Task<ActionResult<DestinationReviewResponse>> GetById(int id)
        => Ok(await _service.GetByIdAsync(id));

    /// <summary>Post a review of an approved destination (author = JWT user; one active per destination).</summary>
    [HttpPost]
    public async Task<ActionResult<DestinationReviewResponse>> Create([FromBody] DestinationReviewInsertRequest request)
        => StatusCode(StatusCodes.Status201Created, await _service.CreateAsync(request));

    /// <summary>Edit your own review.</summary>
    [HttpPut("{id}")]
    public async Task<ActionResult<DestinationReviewResponse>> Update(int id, [FromBody] DestinationReviewUpdateRequest request)
        => Ok(await _service.UpdateAsync(id, request));

    /// <summary>Remove your own review (soft; you may review again afterwards).</summary>
    [HttpDelete("{id}")]
    public async Task<IActionResult> RemoveOwn(int id)
    {
        await _service.RemoveOwnAsync(id);
        return NoContent();
    }

    /// <summary>Admin moderation: soft-remove any review with a mandatory reason (author is notified).</summary>
    [Authorize(Policy = AuthPolicies.AdminOnly)]
    [HttpPost("{id}/Remove")]
    public async Task<ActionResult<DestinationReviewResponse>> Remove(int id, [FromBody] ReviewRemoveRequest request)
        => Ok(await _service.RemoveAsync(id, request));
}
