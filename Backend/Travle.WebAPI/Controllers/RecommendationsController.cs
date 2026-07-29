using Travle.Model.Responses;
using Travle.Services;
using Travle.WebAPI.Authorization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

/// <summary>
/// Personalized recommendations for the current user (04 §5). The user comes from the JWT and every
/// interaction is recorded server-side elsewhere, so there is nothing for the client to post here — one
/// read returns the explained top-N, or a labeled popularity list for cold-start users.
/// </summary>
[ApiController]
[Route("[controller]")]
[Authorize(Policy = AuthPolicies.Authenticated)]
public class RecommendationsController : ControllerBase
{
    private readonly IRecommendationService _service;

    public RecommendationsController(IRecommendationService service)
    {
        _service = service;
    }

    /// <summary>Top-N recommended destinations with reasons; cold-start users get a labeled popularity list.</summary>
    [HttpGet]
    public async Task<ActionResult<RecommendationResponse>> Get()
        => Ok(await _service.GetForCurrentUserAsync());
}
