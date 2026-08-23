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
    public class RegionService
        : ReferenceCrudService<Region, RegionResponse, RegionSearch, RegionInsertRequest, RegionUpdateRequest>,
          IRegionService
    {
        public RegionService(
            TravleDbContext dbContext,
            MapsterMapper.IMapper mapper,
            IValidator<RegionInsertRequest> insertValidator,
            IValidator<RegionUpdateRequest> updateValidator,
            IAppAuthorizationService authorization)
            : base(dbContext, mapper, insertValidator, updateValidator, authorization)
        {
        }

        private static string BlockedReason(string name, int cityCount, int applicationCount)
            => $"Cannot delete region '{name}': it is referenced by {cityCount} city/cities and "
               + $"{applicationCount} role application(s).";

        // Projected list read: usage = cities + role applications pointing at this region.
        public override Task<PageResult<RegionResponse>> GetAllAsync(RegionSearch? search = null)
            => GetPageAsync(
                search,
                r => new RegionResponse
                {
                    Id = r.Id,
                    Name = r.Name,
                    CountryId = r.CountryId,
                    CountryName = r.Country.Name,
                    UsageCount = _dbContext.Cities.Count(c => c.RegionId == r.Id)
                                 + _dbContext.RoleApplications.Count(a => a.RegionId == r.Id),
                    CreatedAt = r.CreatedAt,
                    ModifiedAt = r.ModifiedAt
                },
                row => row.DeleteBlockedReason = row.UsageCount == 0
                    ? null
                    : $"Cannot delete region '{row.Name}': it is still referenced by "
                      + $"{row.UsageCount} other record(s).");

        protected override IQueryable<Region> ApplyFilters(IQueryable<Region> query, RegionSearch? search)
        {
            if (search == null)
            {
                return query;
            }

            query = query.WhereContains(search.Name, r => r.Name);

            if (search.CountryId.HasValue)
            {
                query = query.Where(r => r.CountryId == search.CountryId.Value);
            }

            return query;
        }

        // Single-entity path (GetById / create / update): load the parent so CountryName is populated.
        protected override Task LoadResponseNavigationsAsync(Region entity)
            => _dbContext.Entry(entity).Reference(r => r.Country).LoadAsync();

        protected override async Task OnBeforeInsertAsync(RegionInsertRequest request, Region entity)
        {
            await EnsureCountryExistsAsync(request.CountryId);

            if (await _dbContext.Regions.AnyAsync(r => r.CountryId == request.CountryId && r.Name == request.Name))
            {
                throw new ConflictException($"A region named '{request.Name}' already exists in this country.");
            }
        }

        protected override async Task OnBeforeUpdateAsync(int id, RegionUpdateRequest request, Region entity)
        {
            await EnsureCountryExistsAsync(request.CountryId);

            if (await _dbContext.Regions.AnyAsync(r => r.CountryId == request.CountryId && r.Name == request.Name && r.Id != id))
            {
                throw new ConflictException($"A region named '{request.Name}' already exists in this country.");
            }
        }

        protected override async Task OnBeforeDeleteAsync(Region entity)
        {
            int cityCount = await _dbContext.Cities.CountAsync(c => c.RegionId == entity.Id);
            int applicationCount = await _dbContext.RoleApplications.CountAsync(a => a.RegionId == entity.Id);

            if (cityCount > 0 || applicationCount > 0)
            {
                throw new ConflictException(BlockedReason(entity.Name, cityCount, applicationCount));
            }
        }

        private async Task EnsureCountryExistsAsync(int countryId)
        {
            if (!await _dbContext.Countries.AnyAsync(c => c.Id == countryId))
            {
                throw new BusinessRuleException($"Country with id {countryId} does not exist.");
            }
        }
    }
}
