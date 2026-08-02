using Travle.Model.Responses;
using Travle.Services;
using Travle.WebAPI.Authorization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

/// <summary>
/// Read-only lookup of the four application roles, for the admin user-management screens (create-user
/// role picker + grant/revoke). Admin-only — only user administration needs the full role set (a
/// prospective applicant uses the user-scoped <c>/RoleApplications/applicable-roles</c> instead). Roles
/// are fixed seeded reference data, never written through the API.
/// </summary>
[ApiController]
[Route("[controller]")]
[Authorize(Policy = AuthPolicies.AdminOnly)]
public class RolesController : ControllerBase
{
    private readonly IRoleService _service;

    public RolesController(IRoleService service)
    {
        _service = service;
    }

    [HttpGet]
    public async Task<ActionResult<List<RoleOptionResponse>>> GetAll()
        => Ok(await _service.GetAllAsync());
}
