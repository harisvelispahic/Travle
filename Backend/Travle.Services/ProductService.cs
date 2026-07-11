using System;
using System.Collections.Generic;
using System.Linq;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Database;
using Travle.Services.ProductStateMachine;
using Microsoft.EntityFrameworkCore;

namespace Travle.Services;

public class ProductService : BaseReadService<Product, ProductResponse, ProductSearchObject>, IProductService
{
    protected BaseProductState ProductState { get; }
    public ProductService(TravleDbContext dbContext, MapsterMapper.IMapper mapper, BaseProductState productState) : base(mapper, dbContext)
    {
        ProductState = productState;
    }


    protected override Task<IQueryable<Product>> IncludeRelatedEntitiesAsync(ProductSearchObject? search, IQueryable<Product> query = null)
    {
        if (search?.IncludeProductType == true)
        {
            query = query.Include(p => p.ProductType);
        }
        if (search?.IncludeUnitOfMeasure == true)
        {
            query = query.Include(p => p.UnitOfMeasure);
        }
        if (search?.IncludeAssets == true)
        {
            query = query.Include(p => p.Assets);
        }
        return base.IncludeRelatedEntitiesAsync(search, query);
    }

    protected override IEnumerable<Product> ApplyFilters(IEnumerable<Product> query, ProductSearchObject? search)
    {
        if (search != null)
        {
            if (!string.IsNullOrWhiteSpace(search.Name))
            {
                query = query.Where(p => p.Name.Contains(search.Name, StringComparison.OrdinalIgnoreCase));
            }
            if (!string.IsNullOrWhiteSpace(search.Description))
            {
                query = query.Where(p => p.Description.Contains(search.Description, StringComparison.OrdinalIgnoreCase));
            }
            if (search.ProductTypeId.HasValue)
            {
                query = query.Where(p => p.ProductTypeId == search.ProductTypeId.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.ProductState))
            {
                query = query.Where(p => p.ProductState.Equals(search.ProductState, StringComparison.OrdinalIgnoreCase));
            }
            
        }

        return query;
    }

    public async Task<ProductResponse> ActivateAsync(int id)
    {
        var entity = await _dbContext.Products.FindAsync(id);
        if (entity == null)
        {
            throw new KeyNotFoundException($"Product with id {id} not found.");
        }

        var state = ProductState.GetProductState(entity.ProductState);
        return await state.ActivateAsync(id);
    }

    public async Task<List<string>> GetAllowedActionsAsync(int id)
    {
        if (id <= 0)
        {
             var initialState = ProductState.GetProductState(nameof(InitialProductState));
             return initialState.GetAllowedActions();
        }

        var entity = await _dbContext.Products.FindAsync(id);
        if (entity == null)
        {
            throw new KeyNotFoundException($"Product with id {id} not found.");
        }

        var state = ProductState.GetProductState(entity.ProductState);
        return state.GetAllowedActions();
    }

    public async Task<ProductResponse> DeactivateAsync(int id)
    {
        var entity = await _dbContext.Products.FindAsync(id);
        if (entity == null)
        {
            throw new KeyNotFoundException($"Product with id {id} not found.");
        }

        var state = ProductState.GetProductState(entity.ProductState);
        return await state.DeactivateAsync(id);
    }

    public Task<ProductResponse> InsertAsync(ProductInsertRequest request)
    {
        var state = ProductState.GetProductState(nameof(InitialProductState));
        return state.InsertAsync(request);
    }

    public async Task<ProductResponse> UpdateAsync(int id, ProductUpdateRequest request)
    {
        var entity = await _dbContext.Products.FindAsync(id);
        if (entity == null)
        {
            throw new KeyNotFoundException($"Product with id {id} not found.");
        }

        var state = ProductState.GetProductState(entity.ProductState);
        return await state.UpdateAsync(id, request);
    }

    public async Task DeleteAsync(int id)
    {
        var entity = await _dbContext.Products.FindAsync(id);
        if (entity == null)
        {
            throw new KeyNotFoundException($"Product with id {id} not found.");
        }

        var state = ProductState.GetProductState(entity.ProductState);
        await state.DeleteAsync(id);
    }

    public override async Task<ProductResponse> GetByIdAsync(int id)
    {
        var entity = await _dbContext.Products
            .AsNoTracking()
            .Include(p => p.Reviews.Where(r => r.IsApproved))
            .ThenInclude(r => r.User)
            .Include(p => p.ProductType)
            .Include(p => p.UnitOfMeasure)
            .Include(p => p.Assets)
            .FirstOrDefaultAsync(p => p.Id == id);

        if (entity == null)
        {
            throw new KeyNotFoundException($"Product with id {id} not found.");
        }

        var response = _mapper.Map<ProductResponse>(entity);
        response.AllowedActions = await GetAllowedActionsAsync(id);

        return response;
    }
}