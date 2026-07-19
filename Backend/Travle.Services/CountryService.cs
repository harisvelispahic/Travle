using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Database;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace Travle.Services
{
    public class CountryService
        : BaseCRUDService<Country, CountryResponse, CountrySearch, CountryInsertRequest, CountryUpdateRequest>,
          ICountryService
    {
        public CountryService(
            TravleDbContext dbContext,
            MapsterMapper.IMapper mapper,
            IValidator<CountryInsertRequest> insertValidator,
            IValidator<CountryUpdateRequest> updateValidator)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
        }

        protected override IQueryable<Country> ApplyFilters(IQueryable<Country> query, CountrySearch? search)
        {
            if (!string.IsNullOrWhiteSpace(search?.Name))
            {
                query = query.Where(c => c.Name.Contains(search.Name));
            }

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
                throw new ConflictException(
                    $"Cannot delete country '{entity.Name}': it is referenced by {regionCount} region(s).");
            }
        }
    }
}
