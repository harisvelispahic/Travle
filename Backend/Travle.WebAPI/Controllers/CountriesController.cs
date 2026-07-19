using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

[ApiController]
[Route("[controller]")]
public class CountriesController
    : BaseCRUDController<CountryResponse, CountrySearch, CountryInsertRequest, CountryUpdateRequest, ICountryService>
{
    public CountriesController(ICountryService service) : base(service)
    {
    }
}
