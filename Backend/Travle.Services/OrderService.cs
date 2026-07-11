using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Database;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;

namespace Travle.Services;

public class OrderService : BaseReadService<Order, OrderResponse, OrderSearchObject>, IOrderService
{
    private readonly IAuthenticatedUserAccessor _userAccessor;

    public OrderService(TravleDbContext dbContext, IMapper mapper, IAuthenticatedUserAccessor userAccessor)
        : base(mapper, dbContext)
    {
        _userAccessor = userAccessor;
    }

    public override async Task<PageResult<OrderResponse>> GetAllAsync(OrderSearchObject? search = null)
    {
        search ??= new OrderSearchObject();
        if (string.IsNullOrWhiteSpace(search.SortBy))
        {
            search.SortBy = "OrderDate desc";
        }

        return await base.GetAllAsync(search);
    }

    protected override async Task<IQueryable<Order>> IncludeRelatedEntitiesAsync(
        OrderSearchObject? search,
        IQueryable<Order> query = null!)
    {
        return await Task.FromResult(query.Include(o => o.OrderItems).ThenInclude(oi => oi.Product));
    }

    protected override IEnumerable<Order> ApplyFilters(IEnumerable<Order> query, OrderSearchObject? search)
    {
        var userId = _userAccessor.GetUserId();
        if (!userId.HasValue)
        {
            return Enumerable.Empty<Order>();
        }

        query = query.Where(o => o.UserId == userId.Value);

        if (search?.Status.HasValue == true)
        {
            query = query.Where(o => (int)o.Status == search.Status.Value);
        }

        return query;
    }

    public override async Task<OrderResponse> GetByIdAsync(int id)
    {
        var userId = _userAccessor.GetUserId();
        if (!userId.HasValue)
        {
            throw new KeyNotFoundException($"{typeof(Order).Name} with id {id} not found.");
        }

        var order = await _dbContext.Orders
            .AsNoTracking()
            .Include(o => o.OrderItems)
            .ThenInclude(oi => oi.Product)
            .FirstOrDefaultAsync(o => o.Id == id && o.UserId == userId.Value);

        if (order == null)
        {
            throw new KeyNotFoundException($"{typeof(Order).Name} with id {id} not found.");
        }

        return _mapper.Map<OrderResponse>(order);
    }

    public async Task<OrderResponse> CheckoutAsync(CheckoutRequest request)
    {
        var userId = _userAccessor.GetUserId()
                     ?? throw new InvalidOperationException("User id claim is missing.");

        if (request.Items == null || request.Items.Count == 0)
        {
            throw new ClientException("Cart is empty.");
        }

        await using var tx = await _dbContext.Database.BeginTransactionAsync();

        try
        {
            var merged = request.Items
                .Where(i => i.Quantity > 0)
                .GroupBy(i => i.ProductId)
                .Select(g => new { ProductId = g.Key, Quantity = g.Sum(x => x.Quantity) })
                .ToList();

            decimal total = 0;
            var order = new Order
            {
                UserId = userId,
                OrderDate = DateTime.UtcNow,
                OrderNumber = $"O-{DateTime.UtcNow:yyyyMMddHHmmss}-{userId}",
                Status = OrderStatus.Processing,
                ShippingAddress = OrDash(request.ShippingAddress),
                ShippingCity = OrDash(request.ShippingCity),
                ShippingState = OrDash(request.ShippingState),
                ShippingZipCode = OrDash(request.ShippingZipCode),
                ShippingCountry = OrDash(request.ShippingCountry),
            };

            foreach (var line in merged)
            {
                var product = await _dbContext.Products.FindAsync(line.ProductId);
                if (product == null)
                {
                    throw new ClientException($"Product {line.ProductId} was not found.");
                }

                if (!product.IsActive)
                {
                    throw new ClientException($"Product '{product.Name}' is not available.");
                }

                if (product.StockQuantity < line.Quantity)
                {
                    throw new ClientException($"Insufficient stock for '{product.Name}'.");
                }

                var unitPrice = product.Price;
                total += unitPrice * line.Quantity;
                product.StockQuantity -= line.Quantity;

                order.OrderItems.Add(new OrderItem
                {
                    ProductId = product.Id,
                    Quantity = line.Quantity,
                    UnitPrice = unitPrice,
                });
            }

            order.TotalAmount = total;
            _dbContext.Orders.Add(order);
            await _dbContext.SaveChangesAsync();
            await tx.CommitAsync();

            return await GetByIdAsync(order.Id);
        }
        catch
        {
            await tx.RollbackAsync();
            throw;
        }
    }

    private static string OrDash(string? value) =>
        string.IsNullOrWhiteSpace(value) ? "—" : value.Trim();
}
