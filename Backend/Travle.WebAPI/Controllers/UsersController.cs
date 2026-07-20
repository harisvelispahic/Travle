using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services;
using Travle.WebAPI.Authorization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

/// <summary>
/// User administration and self-service. Read/suspend are admin-only; profile edit and password
/// change are open to any authenticated user but the service enforces "self, or admin" and takes
/// the acting user from the JWT. There is no delete endpoint — users are suspended, never removed
/// (03 §3).
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

    [HttpPut("{id}")]
    public async Task<ActionResult<UserResponse>> Update(int id, [FromBody] UserUpdateRequest request)
        => Ok(await _service.UpdateProfileAsync(id, request));

    [HttpPost("ChangePassword")]
    public async Task<IActionResult> ChangePassword([FromBody] UserPasswordChangeRequest request)
    {
        await _service.ChangePasswordAsync(request);
        return NoContent();
    }

    [Authorize(Policy = AuthPolicies.AdminOnly)]
    [HttpPost("{id}/Suspend")]
    public async Task<ActionResult<UserResponse>> Suspend(int id, [FromBody] UserSuspendRequest request)
        => Ok(await _service.SuspendAsync(id, request));

    [Authorize(Policy = AuthPolicies.AdminOnly)]
    [HttpPost("{id}/Unsuspend")]
    public async Task<ActionResult<UserResponse>> Unsuspend(int id)
        => Ok(await _service.UnsuspendAsync(id));
}
