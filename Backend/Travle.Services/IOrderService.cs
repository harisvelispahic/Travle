using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;

namespace Travle.Services;

public interface IOrderService : IBaseReadService<OrderResponse, OrderSearchObject>
{
    Task<OrderResponse> CheckoutAsync(CheckoutRequest request);
}
