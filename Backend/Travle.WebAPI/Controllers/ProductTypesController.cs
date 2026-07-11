using Travle.Services;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Microsoft.AspNetCore.Mvc;
using Travle.Model.Requests;

namespace Travle.WebAPI.Controllers;

public class ProductTypesController : BaseCRUDController<ProductTypeResponse, ProductTypeSearch, ProductTypeInsertRequest, ProductTypeUpdateRequest, IProductTypeService>
{
    public ProductTypesController(IProductTypeService productTypeService) : base(productTypeService)
    {
    }
}
