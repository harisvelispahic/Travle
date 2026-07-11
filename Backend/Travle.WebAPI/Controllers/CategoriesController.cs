using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

public class CategoriesController : BaseCRUDController<CategoryResponse, CategorySearchObject, CategoriesInsertRequest, CategoriesUpdateRequest, ICategoryService>
{
    public CategoriesController(ICategoryService categoryService) : base(categoryService)
    {
    }

    [AllowAnonymous]
    public override Task<PageResult<CategoryResponse>> GetAll([FromQuery] CategorySearchObject? search)
    {
        return base.GetAll(search);
    }
}