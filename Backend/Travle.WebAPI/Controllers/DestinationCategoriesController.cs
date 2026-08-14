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

    // Full illustration bytes. Category reference data is readable by any authenticated user (the base
    // policy); a category without an image 404s from the service. Lists carry only the thumbnail (§12).
    [HttpGet("{id}/image")]
    public async Task<IActionResult> GetImage(int id)
    {
        var image = await _service.GetImageAsync(id);
        return File(image.Content, image.ContentType);
    }
}
