using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Database;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace Travle.Services
{
    public class DestinationCategoryService
        : BaseCRUDService<DestinationCategory, DestinationCategoryResponse, DestinationCategorySearch, DestinationCategoryInsertRequest, DestinationCategoryUpdateRequest>,
          IDestinationCategoryService
    {
        public DestinationCategoryService(
            TravleDbContext dbContext,
            MapsterMapper.IMapper mapper,
            IValidator<DestinationCategoryInsertRequest> insertValidator,
            IValidator<DestinationCategoryUpdateRequest> updateValidator)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
        }

        protected override IQueryable<DestinationCategory> ApplyFilters(IQueryable<DestinationCategory> query, DestinationCategorySearch? search)
        {
            if (!string.IsNullOrWhiteSpace(search?.Name))
            {
                query = query.Where(c => c.Name.Contains(search.Name));
            }

            return query;
        }

        protected override async Task OnBeforeInsertAsync(DestinationCategoryInsertRequest request, DestinationCategory entity)
        {
            if (await _dbContext.DestinationCategories.AnyAsync(c => c.Name == request.Name))
            {
                throw new ConflictException($"A category named '{request.Name}' already exists.");
            }
        }

        protected override async Task OnBeforeUpdateAsync(int id, DestinationCategoryUpdateRequest request, DestinationCategory entity)
        {
            if (await _dbContext.DestinationCategories.AnyAsync(c => c.Name == request.Name && c.Id != id))
            {
                throw new ConflictException($"A category named '{request.Name}' already exists.");
            }
        }

        protected override async Task OnBeforeDeleteAsync(DestinationCategory entity)
        {
            int destinationCount = await _dbContext.Destinations.CountAsync(d => d.CategoryId == entity.Id);
            int interactionCount = await _dbContext.UserInteractions.CountAsync(i => i.CategoryId == entity.Id);

            if (destinationCount > 0 || interactionCount > 0)
            {
                throw new ConflictException(
                    $"Cannot delete category '{entity.Name}': it is referenced by {destinationCount} destination(s) and {interactionCount} recorded interaction(s).");
            }
        }
    }
}
