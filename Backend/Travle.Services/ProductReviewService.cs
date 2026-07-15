using System.Linq;
using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Database;
using FluentValidation;
using FluentValidation.Results;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;

namespace Travle.Services;

public class ProductReviewService
    : BaseCRUDService<ProductReview, ProductReviewResponse, ProductReviewSearchObject, ProductReviewInsertRequest, ProductReviewUpdateRequest>,
        IProductReviewService
{
    private const string AdminRole = "Admin";

    private readonly IAuthenticatedUserAccessor _userAccessor;

    public ProductReviewService(
        TravleDbContext dbContext,
        IMapper mapper,
        IValidator<ProductReviewInsertRequest> insertValidator,
        IValidator<ProductReviewUpdateRequest> updateValidator,
        IAuthenticatedUserAccessor userAccessor)
        : base(dbContext, mapper, insertValidator, updateValidator)
    {
        _userAccessor = userAccessor;
    }

    public override async Task<PageResult<ProductReviewResponse>> GetAllAsync(ProductReviewSearchObject? search = null)
    {
        search ??= new ProductReviewSearchObject();
        if (string.IsNullOrWhiteSpace(search.SortBy))
        {
            search.SortBy = "CreatedAt desc";
        }

        return await base.GetAllAsync(search);
    }

    protected override async Task<IQueryable<ProductReview>> IncludeRelatedEntitiesAsync(
        ProductReviewSearchObject? search,
        IQueryable<ProductReview> query = null!)
    {
        return await Task.FromResult(query.Include(r => r.User));
    }

    protected override IEnumerable<ProductReview> ApplyFilters(IEnumerable<ProductReview> query, ProductReviewSearchObject? search)
    {
        if (_userAccessor.IsInRole(AdminRole))
        {
            if (search?.UserId.HasValue == true)
            {
                query = query.Where(r => r.UserId == search.UserId.Value);
            }
        }
        else
        {
            var userId = _userAccessor.GetUserId();
            if (userId.HasValue)
            {
                query = query.Where(r => r.UserId == userId.Value);
            }
        }

        if (search?.ProductId.HasValue == true)
        {
            query = query.Where(r => r.ProductId == search.ProductId.Value);
        }

        if (search?.OrderId.HasValue == true)
        {
            query = query.Where(r => r.OrderId == search.OrderId.Value);
        }

        if (search?.Rating.HasValue == true)
        {
            query = query.Where(r => r.Rating == search.Rating.Value);
        }

        return query;
    }

    public override async Task<ProductReviewResponse> InsertAsync(ProductReviewInsertRequest request)
    {
        var userId = _userAccessor.GetUserId()
                     ?? throw new InvalidOperationException("User id claim is missing.");

        var validationResult = await _insertValidator.ValidateAsync(request);
        if (!validationResult.IsValid)
        {
            var errors = validationResult.Errors.Select(e => _mapper.Map<ValidationFailure>(e));
            throw new FluentValidation.ValidationException(errors);
        }

        var order = await _dbContext.Orders
            .Include(o => o.OrderItems)
            .FirstOrDefaultAsync(o => o.Id == request.OrderId && o.UserId == userId);

        if (order == null)
        {
            throw new BusinessRuleException("Order not found.");
        }

        if (order.Status == OrderStatus.Cancelled)
        {
            throw new BusinessRuleException("Cannot review items from a cancelled order.");
        }

        if (order.OrderItems.All(oi => oi.ProductId != request.ProductId))
        {
            throw new BusinessRuleException("This product is not part of the selected order.");
        }

        var duplicate = await _dbContext.ProductReviews.AnyAsync(r =>
            r.UserId == userId && r.ProductId == request.ProductId && r.OrderId == request.OrderId);

        if (duplicate)
        {
            throw new BusinessRuleException("You have already reviewed this product for this order.");
        }

        var review = new ProductReview
        {
            UserId = userId,
            ProductId = request.ProductId,
            OrderId = request.OrderId,
            Rating = request.Rating,
            Comment = request.Comment?.Trim() ?? string.Empty,
            IsApproved = true,
            CreatedAt = DateTime.UtcNow,
        };

        _dbContext.ProductReviews.Add(review);
        await _dbContext.SaveChangesAsync();

        var loaded = await _dbContext.ProductReviews
            .AsNoTracking()
            .Include(r => r.User)
            .FirstAsync(r => r.Id == review.Id);

        return _mapper.Map<ProductReviewResponse>(loaded);
    }

    public override async Task<ProductReviewResponse> GetByIdAsync(int id)
    {
        var userId = _userAccessor.GetUserId()
                     ?? throw new InvalidOperationException("User id claim is missing.");

        var review = await _dbContext.ProductReviews
            .AsNoTracking()
            .Include(r => r.User)
            .FirstOrDefaultAsync(r => r.Id == id);

        var isAdmin = _userAccessor.IsInRole(AdminRole);
        if (review == null || (!isAdmin && review.UserId != userId))
        {
            throw new NotFoundException($"{nameof(ProductReview)} with id {id} not found.");
        }

        return _mapper.Map<ProductReviewResponse>(review);
    }

    public override async Task<ProductReviewResponse> UpdateAsync(int id, ProductReviewUpdateRequest request)
    {
        var userId = _userAccessor.GetUserId()
                     ?? throw new InvalidOperationException("User id claim is missing.");

        var validationResult = await _updateValidator.ValidateAsync(request);
        if (!validationResult.IsValid)
        {
            var errors = validationResult.Errors.Select(e => _mapper.Map<ValidationFailure>(e));
            throw new FluentValidation.ValidationException(errors);
        }

        var entity = await _dbContext.ProductReviews.FindAsync(id);
        if (entity == null)
        {
            throw new NotFoundException($"{nameof(ProductReview)} with id {id} not found.");
        }

        if (entity.UserId != userId)
        {
            throw new NotFoundException($"{nameof(ProductReview)} with id {id} not found.");
        }

        MapUpdateRequestToEntity(request, entity);
        await _dbContext.SaveChangesAsync();

        var loaded = await _dbContext.ProductReviews
            .AsNoTracking()
            .Include(r => r.User)
            .FirstAsync(r => r.Id == id);

        return _mapper.Map<ProductReviewResponse>(loaded);
    }

    public override async Task DeleteAsync(int id)
    {
        var userId = _userAccessor.GetUserId()
                     ?? throw new InvalidOperationException("User id claim is missing.");

        var entity = await _dbContext.ProductReviews.FindAsync(id);
        if (entity == null)
        {
            throw new NotFoundException($"{nameof(ProductReview)} with id {id} not found.");
        }

        if (entity.UserId != userId)
        {
            throw new NotFoundException($"{nameof(ProductReview)} with id {id} not found.");
        }

        _dbContext.ProductReviews.Remove(entity);
        await _dbContext.SaveChangesAsync();
    }
}
