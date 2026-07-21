using Travle.Model.SearchObjects;
using Travle.Services;
using Travle.WebAPI.Authorization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

/// <summary>
/// Base controller for admin-managed reference data (spec §2.4). Reads (GetAll/GetById, inherited from
/// <see cref="BaseReadController{TResponse,TSearch,TService}"/>) require an authenticated user; writes
/// (Create/Update/Delete) require the Admin role. The paired <c>ReferenceCrudService</c> enforces the
/// same Admin rule on writes, so authorization holds at both the API and the service layer.
/// </summary>
[Authorize(Policy = AuthPolicies.Authenticated)]
public abstract class ReferenceCrudController<TResponse, TSearch, TInsertRequest, TUpdateRequest, TService>
    : BaseCRUDController<TResponse, TSearch, TInsertRequest, TUpdateRequest, TService>
    where TSearch : BaseSearchObject
    where TService : IBaseCRUDService<TResponse, TSearch, TInsertRequest, TUpdateRequest>
{
    protected ReferenceCrudController(TService service) : base(service)
    {
    }

    [Authorize(Policy = AuthPolicies.AdminOnly)]
    [HttpPost]
    public override Task<ActionResult<TResponse>> Create([FromBody] TInsertRequest request)
        => base.Create(request);

    [Authorize(Policy = AuthPolicies.AdminOnly)]
    [HttpPut("{id}")]
    public override Task<ActionResult<TResponse>> Update(int id, [FromBody] TUpdateRequest request)
        => base.Update(id, request);

    [Authorize(Policy = AuthPolicies.AdminOnly)]
    [HttpDelete("{id}")]
    public override Task<IActionResult> Delete(int id)
        => base.Delete(id);
}
