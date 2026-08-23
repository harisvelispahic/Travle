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
    public class CountryService
        : ReferenceCrudService<Country, CountryResponse, CountrySearch, CountryInsertRequest, CountryUpdateRequest>,
          ICountryService
    {
        public CountryService(
            TravleDbContext dbContext,
            MapsterMapper.IMapper mapper,
            IValidator<CountryInsertRequest> insertValidator,
            IValidator<CountryUpdateRequest> updateValidator,
            IAppAuthorizationService authorization)
            : base(dbContext, mapper, insertValidator, updateValidator, authorization)
        {
        }

        /// <summary>The one sentence used both as the disabled-Delete reason and as the conflict message.</summary>
        private static string BlockedReason(string name, int regionCount)
            => $"Cannot delete country '{name}': it is referenced by {regionCount} region(s).";

        // Projected list read: each row carries how many regions reference it, so the desktop can render
        // Delete disabled with the reason instead of only failing on click (course §6).
        public override Task<PageResult<CountryResponse>> GetAllAsync(CountrySearch? search = null)
            => GetPageAsync(
                search,
                c => new CountryResponse
                {
                    Id = c.Id,
                    Name = c.Name,
                    UsageCount = _dbContext.Regions.Count(r => r.CountryId == c.Id),
                    CreatedAt = c.CreatedAt,
                    ModifiedAt = c.ModifiedAt
                },
                row => row.DeleteBlockedReason =
                    row.UsageCount == 0 ? null : BlockedReason(row.Name, row.UsageCount));

        protected override IQueryable<Country> ApplyFilters(IQueryable<Country> query, CountrySearch? search)
        {
            query = query.WhereContains(search?.Name, c => c.Name);

            return query;
        }

        protected override async Task OnBeforeInsertAsync(CountryInsertRequest request, Country entity)
        {
            if (await _dbContext.Countries.AnyAsync(c => c.Name == request.Name))
            {
                throw new ConflictException($"A country named '{request.Name}' already exists.");
            }
        }

        protected override async Task OnBeforeUpdateAsync(int id, CountryUpdateRequest request, Country entity)
        {
            if (await _dbContext.Countries.AnyAsync(c => c.Name == request.Name && c.Id != id))
            {
                throw new ConflictException($"A country named '{request.Name}' already exists.");
            }
        }

        protected override async Task OnBeforeDeleteAsync(Country entity)
        {
            int regionCount = await _dbContext.Regions.CountAsync(r => r.CountryId == entity.Id);
            if (regionCount > 0)
            {
                throw new ConflictException(BlockedReason(entity.Name, regionCount));
            }
        }
    }
}
