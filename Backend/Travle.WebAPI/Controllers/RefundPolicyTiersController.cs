using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

[ApiController]
[Route("[controller]")]
public class RefundPolicyTiersController
    : ReferenceCrudController<RefundPolicyTierResponse, RefundPolicyTierSearch, RefundPolicyTierInsertRequest, RefundPolicyTierUpdateRequest, IRefundPolicyTierService>
{
    public RefundPolicyTiersController(IRefundPolicyTierService service) : base(service)
    {
    }

    /// <summary>
    /// Replaces the whole refund ladder at once (Admin only, enforced in the service). The ladder is one
    /// aggregate — its rungs have to tile every hour before departure exactly once — so it is edited as a
    /// set rather than a row at a time.
    /// </summary>
    [HttpPut("ladder")]
    public async Task<ActionResult<List<RefundPolicyTierResponse>>> ReplaceLadder(
        [FromBody] RefundPolicyLadderRequest request)
        => Ok(await _service.ReplaceLadderAsync(request));
}
