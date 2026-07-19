using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

[ApiController]
[Route("[controller]")]
public class RegionsController
    : BaseCRUDController<RegionResponse, RegionSearch, RegionInsertRequest, RegionUpdateRequest, IRegionService>
{
    public RegionsController(IRegionService service) : base(service)
    {
    }
}
