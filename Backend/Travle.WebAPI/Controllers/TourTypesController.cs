using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

[ApiController]
[Route("[controller]")]
public class TourTypesController
    : ReferenceCrudController<TourTypeResponse, TourTypeSearch, TourTypeInsertRequest, TourTypeUpdateRequest, ITourTypeService>
{
    public TourTypesController(ITourTypeService service) : base(service)
    {
    }
}
