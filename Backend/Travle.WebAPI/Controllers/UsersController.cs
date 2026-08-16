using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services;
using Travle.WebAPI.Authorization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

/// <summary>
/// User administration and self-service. Admin-only: list/read, create, suspend/unsuspend, and role
/// grant/revoke. Profile edit and password change are open to any authenticated user but the service
/// enforces "self, or admin" and takes the acting user from the JWT. There is no delete endpoint —
/// users are suspended, never removed (03 §3); admin edit of another user's profile is intentionally
/// absent (suspension and role management are the only admin mutations).
/// </summary>
[ApiController]
[Route("[controller]")]
[Authorize(Policy = AuthPolicies.Authenticated)]
public class UsersController : BaseReadController<UserResponse, UserSearch, IUserService>
{
    public UsersController(IUserService service) : base(service)
    {
    }

    [Authorize(Policy = AuthPolicies.AdminOnly)]
    public override Task<PageResult<UserResponse>> GetAll([FromQuery] UserSearch? search)
        => base.GetAll(search);

    [Authorize(Policy = AuthPolicies.AdminOnly)]
    public override Task<ActionResult<UserResponse>> GetById(int id)
        => base.GetById(id);

    // Admin account creation — the only path to an Admin account, and to any multi-role account. Distinct
    // from the anonymous, Traveler-only self-registration at POST /Access/Register.
    [Authorize(Policy = AuthPolicies.AdminOnly)]
    [HttpPost]
    public async Task<ActionResult<UserResponse>> Create([FromBody] AdminCreateUserRequest request)
        => Ok(await _service.CreateAsync(request));

    [Authorize(Policy = AuthPolicies.AdminOnly)]
    [HttpPost("{id}/Roles")]
    public async Task<ActionResult<UserResponse>> GrantRole(int id, [FromBody] UserRoleGrantRequest request)
        => Ok(await _service.GrantRoleAsync(id, request));

    [Authorize(Policy = AuthPolicies.AdminOnly)]
    [HttpDelete("{id}/Roles/{roleId}")]
    public async Task<ActionResult<UserResponse>> RevokeRole(int id, int roleId)
        => Ok(await _service.RevokeRoleAsync(id, roleId));

    [HttpPut("{id}")]
    public async Task<ActionResult<UserResponse>> Update(int id, [FromBody] UserUpdateRequest request)
        => Ok(await _service.UpdateProfileAsync(id, request));

    [HttpPost("ChangePassword")]
    public async Task<IActionResult> ChangePassword([FromBody] UserPasswordChangeRequest request)
    {
        await _service.ChangePasswordAsync(request);
        return NoContent();
    }

    // Post-registration interest picks (04 §5). Travelers only — other roles don't use the app for
    // travel, so onboarding (which seeds travel recommendations) doesn't apply. Current user from the
    // JWT; an empty body is a skip. A multi-role Curator+Traveler still qualifies (holds Traveler).
    [Authorize(Policy = AuthPolicies.TravelerOnly)]
    [HttpPost("onboarding-interests")]
    public async Task<ActionResult<UserResponse>> OnboardingInterests([FromBody] UserOnboardingRequest request)
        => Ok(await _service.CompleteOnboardingAsync(request));

    // Records that the onboarding step was shown (per-display prompt cap). Traveler-only; current user
    // from the JWT. The client calls this each time it displays onboarding on app entry.
    [Authorize(Policy = AuthPolicies.TravelerOnly)]
    [HttpPost("onboarding-prompt")]
    public async Task<ActionResult<UserResponse>> OnboardingPrompt()
        => Ok(await _service.RegisterOnboardingPromptAsync());

    // Public organizer profile a traveler sees while deciding whether to book one of the organizer's
    // tours: name, home city, member-since, avatar, a computed average rating, and their top tours. Any
    // authenticated user (the class-level policy) — contact details are never exposed. 404 if the id is
    // not an active organizer.
    [HttpGet("{id}/organizer-profile")]
    public async Task<ActionResult<OrganizerProfileResponse>> OrganizerProfile(int id)
        => Ok(await _service.GetOrganizerProfileAsync(id));

    [Authorize(Policy = AuthPolicies.AdminOnly)]
    [HttpPost("{id}/Suspend")]
    public async Task<ActionResult<UserResponse>> Suspend(int id, [FromBody] UserSuspendRequest request)
        => Ok(await _service.SuspendAsync(id, request));

    [Authorize(Policy = AuthPolicies.AdminOnly)]
    [HttpPost("{id}/Unsuspend")]
    public async Task<ActionResult<UserResponse>> Unsuspend(int id)
        => Ok(await _service.UnsuspendAsync(id));
}
