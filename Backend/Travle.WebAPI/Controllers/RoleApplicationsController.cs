using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services;
using Travle.WebAPI.Authorization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

/// <summary>
/// Curator/Organizer role applications. Any authenticated user may submit and read their own
/// applications; the moderation queue and the approve/reject decisions are admin-only. There is no
/// delete endpoint — applications are status-driven and their history is retained (03 §deletion).
/// </summary>
[ApiController]
[Route("[controller]")]
[Authorize(Policy = AuthPolicies.Authenticated)]
public class RoleApplicationsController
    : BaseReadController<RoleApplicationResponse, RoleApplicationSearch, IRoleApplicationService>
{
    public RoleApplicationsController(IRoleApplicationService service) : base(service)
    {
    }

    // Admin moderation queue (filter by ?status=0 for Pending). GetById stays owner-or-admin (the
    // service enforces ownership), so it keeps the class-level Authenticated policy.
    [Authorize(Policy = AuthPolicies.AdminOnly)]
    public override Task<PageResult<RoleApplicationResponse>> GetAll([FromQuery] RoleApplicationSearch? search)
        => base.GetAll(search);

    [HttpGet("mine")]
    public async Task<ActionResult<PageResult<RoleApplicationResponse>>> GetMine([FromQuery] RoleApplicationSearch? search)
        => Ok(await _service.GetMineAsync(search));

    // The elevated roles the current user may still apply for (drives the "Become a curator" screen so
    // the client resolves the target role id by name rather than hardcoding it).
    [HttpGet("applicable-roles")]
    public async Task<ActionResult<List<RoleOptionResponse>>> ApplicableRoles()
        => Ok(await _service.GetApplicableRolesAsync());

    [HttpPost]
    public async Task<ActionResult<RoleApplicationResponse>> Submit([FromBody] RoleApplicationSubmitRequest request)
        => Ok(await _service.SubmitAsync(request));

    [Authorize(Policy = AuthPolicies.AdminOnly)]
    [HttpPost("{id}/Approve")]
    public async Task<ActionResult<RoleApplicationResponse>> Approve(int id)
        => Ok(await _service.ApproveAsync(id));

    [Authorize(Policy = AuthPolicies.AdminOnly)]
    [HttpPost("{id}/Reject")]
    public async Task<ActionResult<RoleApplicationResponse>> Reject(int id, [FromBody] RoleApplicationRejectRequest request)
        => Ok(await _service.RejectAsync(id, request));

    // Supporting-document download (owner-or-admin, enforced in the service). A missing attachment is
    // a 404 rather than an empty file.
    [HttpGet("{id}/document")]
    public async Task<IActionResult> GetDocument(int id)
    {
        var document = await _service.GetDocumentAsync(id)
            ?? throw new NotFoundException("Document", id);

        return File(document.Content, document.ContentType);
    }
}
