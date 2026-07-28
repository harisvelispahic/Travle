using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services;
using Travle.WebAPI.Authorization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

/// <summary>
/// Favorites for the current user: a single toggle over one target (destination or tour) and the two
/// "my favorites" lists. The user id always comes from the JWT (never the request), so a caller can only
/// ever read or change their own favorites.
/// </summary>
[ApiController]
[Route("[controller]")]
[Authorize(Policy = AuthPolicies.Authenticated)]
public class FavoritesController : ControllerBase
{
    private readonly IFavoriteService _service;

    public FavoritesController(IFavoriteService service)
    {
        _service = service;
    }

    /// <summary>Toggle a destination or tour in the current user's favorites; returns the resulting state.</summary>
    [HttpPost("Toggle")]
    public async Task<ActionResult<FavoriteToggleResponse>> Toggle([FromBody] FavoriteToggleRequest request)
        => Ok(await _service.ToggleAsync(request));

    /// <summary>The current user's favorited destinations (cards), newest favorited first, paginated.</summary>
    [HttpGet("destinations")]
    public async Task<ActionResult<PageResult<DestinationResponse>>> GetMyDestinations([FromQuery] DestinationSearch? search)
        => Ok(await _service.GetMyDestinationsAsync(search));

    /// <summary>The current user's favorited tours (cards), newest favorited first, paginated.</summary>
    [HttpGet("tours")]
    public async Task<ActionResult<PageResult<TourResponse>>> GetMyTours([FromQuery] TourSearch? search)
        => Ok(await _service.GetMyToursAsync(search));
}
