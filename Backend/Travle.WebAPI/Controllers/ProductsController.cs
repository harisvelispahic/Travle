using Travle.Services;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Microsoft.AspNetCore.Mvc;
using Travle.Model.Requests;

namespace Travle.WebAPI.Controllers;

public class ProductsController : BaseCRUDController<ProductResponse, ProductSearchObject, ProductInsertRequest, ProductUpdateRequest, IProductService>
{
    public ProductsController(IProductService productService) : base(productService)
    {
    }

    [HttpPost("{id}/Activate")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ProductResponse>> Activate(int id)
    {
        var result = await _service.ActivateAsync(id);
        return Ok(result);
    }

    [HttpPost("{id}/Deactivate")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ProductResponse>> Deactivate(int id)
    {
        var result = await _service.DeactivateAsync(id);
        return Ok(result); 
    }

    [HttpGet("{id}/AllowedActions")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<List<string>>> GetAllowedActions(int id)
    {        
        var result = await _service.GetAllowedActionsAsync(id);
        return Ok(result);
    }

}
