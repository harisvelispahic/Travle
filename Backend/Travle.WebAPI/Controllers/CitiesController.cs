using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

[ApiController]
[Route("[controller]")]
public class CitiesController
    : BaseCRUDController<CityResponse, CitySearch, CityInsertRequest, CityUpdateRequest, ICityService>
{
    public CitiesController(ICityService service) : base(service)
    {
    }
}
