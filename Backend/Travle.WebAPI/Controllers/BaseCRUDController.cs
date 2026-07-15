using Microsoft.AspNetCore.Mvc;
using Travle.Services;
using Travle.Model.SearchObjects;

namespace Travle.WebAPI.Controllers;

/// <summary>
/// Generic base controller for CRUD operations (Create, Read, Update, Delete)
/// </summary>
/// <typeparam name="TResponse">The response model type</typeparam>
/// <typeparam name="TSearch">The search/filter object type</typeparam>
/// <typeparam name="TInsertRequest">The insert request model type</typeparam>
/// <typeparam name="TUpdateRequest">The update request model type</typeparam>
/// <typeparam name="TService">The service interface type implementing CRUD operations</typeparam>
[ApiController]
[Route("[controller]")]
public abstract class BaseCRUDController<TResponse, TSearch, TInsertRequest, TUpdateRequest, TService>
    : BaseReadController<TResponse, TSearch, TService>
    where TSearch : BaseSearchObject
    where TService : IBaseCRUDService<TResponse, TSearch, TInsertRequest, TUpdateRequest>
{
    protected BaseCRUDController(TService service) : base(service)
    {
    }

    [HttpPost]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public virtual async Task<ActionResult<TResponse>> Create([FromBody] TInsertRequest request)
    {
        var result = await _service.InsertAsync(request);
        // 201 Created with the new resource in the body. No Location header: the surrogate id isn't
        // available generically here — a concrete controller can override to add CreatedAtAction.
        return StatusCode(StatusCodes.Status201Created, result);
    }

    [HttpPut("{id}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public virtual async Task<ActionResult<TResponse>> Update(int id, [FromBody] TUpdateRequest request)
    {
        var result = await _service.UpdateAsync(id, request);
        return Ok(result);
    }

    [HttpDelete("{id}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public virtual async Task<IActionResult> Delete(int id)
    {
        await _service.DeleteAsync(id);
        return NoContent();
    }
}
