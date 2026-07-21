using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Authorization;
using Travle.Services.Database;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace Travle.Services
{
    public class TourTypeService
        : ReferenceCrudService<TourType, TourTypeResponse, TourTypeSearch, TourTypeInsertRequest, TourTypeUpdateRequest>,
          ITourTypeService
    {
        public TourTypeService(
            TravleDbContext dbContext,
            MapsterMapper.IMapper mapper,
            IValidator<TourTypeInsertRequest> insertValidator,
            IValidator<TourTypeUpdateRequest> updateValidator,
            IAppAuthorizationService authorization)
            : base(dbContext, mapper, insertValidator, updateValidator, authorization)
        {
        }

        protected override IQueryable<TourType> ApplyFilters(IQueryable<TourType> query, TourTypeSearch? search)
        {
            if (!string.IsNullOrWhiteSpace(search?.Name))
            {
                query = query.Where(t => t.Name.Contains(search.Name));
            }

            return query;
        }

        protected override async Task OnBeforeInsertAsync(TourTypeInsertRequest request, TourType entity)
        {
            if (await _dbContext.TourTypes.AnyAsync(t => t.Name == request.Name))
            {
                throw new ConflictException($"A tour type named '{request.Name}' already exists.");
            }
        }

        protected override async Task OnBeforeUpdateAsync(int id, TourTypeUpdateRequest request, TourType entity)
        {
            if (await _dbContext.TourTypes.AnyAsync(t => t.Name == request.Name && t.Id != id))
            {
                throw new ConflictException($"A tour type named '{request.Name}' already exists.");
            }
        }

        protected override async Task OnBeforeDeleteAsync(TourType entity)
        {
            int tourCount = await _dbContext.Tours.CountAsync(t => t.TourTypeId == entity.Id);
            if (tourCount > 0)
            {
                throw new ConflictException(
                    $"Cannot delete tour type '{entity.Name}': it is referenced by {tourCount} tour(s).");
            }
        }
    }
}
