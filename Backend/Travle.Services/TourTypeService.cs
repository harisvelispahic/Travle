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

        private static string BlockedReason(string name, int tourCount)
            => $"Cannot delete tour type '{name}': it is referenced by {tourCount} tour(s).";

        // Projected list read: usage = tours of this type.
        public override Task<PageResult<TourTypeResponse>> GetAllAsync(TourTypeSearch? search = null)
            => GetPageAsync(
                search,
                t => new TourTypeResponse
                {
                    Id = t.Id,
                    Name = t.Name,
                    UsageCount = _dbContext.Tours.Count(tour => tour.TourTypeId == t.Id),
                    CreatedAt = t.CreatedAt,
                    ModifiedAt = t.ModifiedAt
                },
                row => row.DeleteBlockedReason =
                    row.UsageCount == 0 ? null : BlockedReason(row.Name, row.UsageCount));

        protected override IQueryable<TourType> ApplyFilters(IQueryable<TourType> query, TourTypeSearch? search)
        {
            query = query.WhereContains(search?.Name, t => t.Name);

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
                throw new ConflictException(BlockedReason(entity.Name, tourCount));
            }
        }
    }
}
