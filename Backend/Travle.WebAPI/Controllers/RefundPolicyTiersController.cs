using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

[ApiController]
[Route("[controller]")]
public class RefundPolicyTiersController
    : BaseCRUDController<RefundPolicyTierResponse, RefundPolicyTierSearch, RefundPolicyTierInsertRequest, RefundPolicyTierUpdateRequest, IRefundPolicyTierService>
{
    public RefundPolicyTiersController(IRefundPolicyTierService service) : base(service)
    {
    }
}
