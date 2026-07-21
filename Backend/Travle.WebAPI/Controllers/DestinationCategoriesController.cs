using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

[ApiController]
[Route("[controller]")]
public class DestinationCategoriesController
    : ReferenceCrudController<DestinationCategoryResponse, DestinationCategorySearch, DestinationCategoryInsertRequest, DestinationCategoryUpdateRequest, IDestinationCategoryService>
{
    public DestinationCategoriesController(IDestinationCategoryService service) : base(service)
    {
    }
}
