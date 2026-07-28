using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services;
using Travle.WebAPI.Authorization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

/// <summary>
/// Tour reviews. Any authenticated user may read a tour's reviews; a traveler posts a review for their own
/// Completed booking and edits their own; an organizer reads the reviews across their own tours; admins
/// moderate (remove with a reason). Gating (own Completed booking, one review per booking, author-only
/// edits, admin-only removal) lives in the service. Tours are never deleted through review flows.
/// </summary>
[ApiController]
[Route("[controller]")]
[Authorize(Policy = AuthPolicies.Authenticated)]
public class TourReviewsController : ControllerBase
{
    private readonly ITourReviewService _service;

    public TourReviewsController(ITourReviewService service)
    {
        _service = service;
    }

    /// <summary>A tour's reviews (filter by tour/user/rating), paginated. Removed rows are admin-only.</summary>
    [HttpGet]
    public async Task<ActionResult<PageResult<TourReviewResponse>>> GetAll([FromQuery] TourReviewSearch? search)
        => Ok(await _service.GetAllAsync(search));

    /// <summary>Reviews across the current organizer's own tours.</summary>
    [Authorize(Policy = AuthPolicies.OrganizerOnly)]
    [HttpGet("my-tours")]
    public async Task<ActionResult<PageResult<TourReviewResponse>>> GetForMyTours([FromQuery] TourReviewSearch? search)
        => Ok(await _service.GetForMyToursAsync(search));

    [HttpGet("{id}")]
    public async Task<ActionResult<TourReviewResponse>> GetById(int id)
        => Ok(await _service.GetByIdAsync(id));

    /// <summary>Post a review for your own Completed booking (one review per booking).</summary>
    [HttpPost]
    public async Task<ActionResult<TourReviewResponse>> Create([FromBody] TourReviewInsertRequest request)
        => StatusCode(StatusCodes.Status201Created, await _service.CreateAsync(request));

    /// <summary>Edit your own review.</summary>
    [HttpPut("{id}")]
    public async Task<ActionResult<TourReviewResponse>> Update(int id, [FromBody] TourReviewUpdateRequest request)
        => Ok(await _service.UpdateAsync(id, request));

    /// <summary>Remove your own review (soft; you may review this booking again afterwards).</summary>
    [HttpDelete("{id}")]
    public async Task<IActionResult> RemoveOwn(int id)
    {
        await _service.RemoveOwnAsync(id);
        return NoContent();
    }

    /// <summary>Admin moderation: soft-remove any review with a mandatory reason (author is notified).</summary>
    [Authorize(Policy = AuthPolicies.AdminOnly)]
    [HttpPost("{id}/Remove")]
    public async Task<ActionResult<TourReviewResponse>> Remove(int id, [FromBody] ReviewRemoveRequest request)
        => Ok(await _service.RemoveAsync(id, request));
}
