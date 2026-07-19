using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

[ApiController]
[Route("[controller]")]
public class TagsController
    : BaseCRUDController<TagResponse, TagSearch, TagInsertRequest, TagUpdateRequest, ITagService>
{
    public TagsController(ITagService service) : base(service)
    {
    }
}
