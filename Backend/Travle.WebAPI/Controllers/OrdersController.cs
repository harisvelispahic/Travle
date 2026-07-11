using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

[Authorize]
public class OrdersController : BaseReadController<OrderResponse, OrderSearchObject, IOrderService>
{
    public OrdersController(IOrderService orderService)
        : base(orderService)
    {
    }

    [HttpPost("Checkout")]
    [ProducesResponseType(typeof(OrderResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<OrderResponse>> Checkout([FromBody] CheckoutRequest request)
    {
        var result = await _service.CheckoutAsync(request);
        return Ok(result);
    }
}
