using Microsoft.AspNetCore.Mvc;
using Travle.Services;
using Travle.Model.SearchObjects;
using Travle.Model.Responses;
using Microsoft.AspNetCore.Authorization;

namespace Travle.WebAPI.Controllers;

/// <summary>
/// Generic base controller for read-only operations (GetAll, GetById)
/// </summary>
/// <typeparam name="TResponse">The response model type</typeparam>
/// <typeparam name="TSearch">The search/filter object type</typeparam>
/// <typeparam name="TService">The service interface type implementing IBaseReadService</typeparam>
//[Authorize]
[ApiController]
[Route("[controller]")]
public abstract class BaseReadController<TResponse, TSearch, TService> : ControllerBase
    where TSearch : BaseSearchObject
    where TService : IBaseReadService<TResponse, TSearch>
{
    protected readonly TService _service;

    protected BaseReadController(TService service)
    {
        _service = service;
    }

    [HttpGet]
    public virtual async Task<PageResult<TResponse>> GetAll([FromQuery] TSearch? search)
    {
        var results = await _service.GetAllAsync(search);
        return results;
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<TResponse>> GetById(int id)
    {
        // A missing entity surfaces as NotFoundException from the service and is turned into a
        // 404 by the global exception-handling pipeline — controllers stay free of try/catch.
        var result = await _service.GetByIdAsync(id);
        return Ok(result);
    }
}
