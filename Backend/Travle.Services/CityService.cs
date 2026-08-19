using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Authorization;
using Travle.Services.Database;
using Travle.Services.Time;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace Travle.Services
{
    public class CityService
        : ReferenceCrudService<City, CityResponse, CitySearch, CityInsertRequest, CityUpdateRequest>,
          ICityService
    {
        private readonly ITimeZoneService _timeZones;

        public CityService(
            TravleDbContext dbContext,
            MapsterMapper.IMapper mapper,
            IValidator<CityInsertRequest> insertValidator,
            IValidator<CityUpdateRequest> updateValidator,
            IAppAuthorizationService authorization,
            ITimeZoneService timeZones)
            : base(dbContext, mapper, insertValidator, updateValidator, authorization)
        {
            _timeZones = timeZones;
        }

        // A blank zone on insert inherits the platform default; a provided one must be a real IANA id.
        protected override City MapInsertRequestToEntity(CityInsertRequest request)
        {
            var entity = base.MapInsertRequestToEntity(request);
            entity.TimeZoneId = string.IsNullOrWhiteSpace(request.TimeZoneId)
                ? _timeZones.PlatformTimeZoneId
                : ValidateZone(request.TimeZoneId);
            return entity;
        }

        // A blank zone on update keeps the stored one; a provided one must be a real IANA id. Captured
        // before the base map because Mapster would otherwise overwrite the existing value with null.
        protected override void MapUpdateRequestToEntity(CityUpdateRequest request, City entity)
        {
            var existingZone = entity.TimeZoneId;
            base.MapUpdateRequestToEntity(request, entity);
            entity.TimeZoneId = string.IsNullOrWhiteSpace(request.TimeZoneId)
                ? existingZone
                : ValidateZone(request.TimeZoneId);
        }

        private string ValidateZone(string timeZoneId)
        {
            var trimmed = timeZoneId.Trim();
            if (!_timeZones.IsKnownZone(trimmed))
            {
                throw new BusinessRuleException(
                    $"'{trimmed}' is not a valid IANA time-zone identifier (e.g. 'Europe/Sarajevo').");
            }
            return trimmed;
        }

        protected override IQueryable<City> ApplyFilters(IQueryable<City> query, CitySearch? search)
        {
            if (search == null)
            {
                return query;
            }

            query = query.WhereContains(search.Name, c => c.Name);

            if (search.RegionId.HasValue)
            {
                query = query.Where(c => c.RegionId == search.RegionId.Value);
            }

            return query;
        }

        // List path: JOIN the parent so Mapster flattens Region.Name -> CityResponse.RegionName.
        protected override IQueryable<City> ApplyIncludes(IQueryable<City> query, CitySearch? search)
            => query.Include(c => c.Region);

        // Single-entity path (GetById / create / update): load the parent so RegionName is populated.
        protected override Task LoadResponseNavigationsAsync(City entity)
            => _dbContext.Entry(entity).Reference(c => c.Region).LoadAsync();

        protected override async Task OnBeforeInsertAsync(CityInsertRequest request, City entity)
        {
            await EnsureRegionExistsAsync(request.RegionId);

            if (await _dbContext.Cities.AnyAsync(c => c.RegionId == request.RegionId && c.Name == request.Name))
            {
                throw new ConflictException($"A city named '{request.Name}' already exists in this region.");
            }
        }

        protected override async Task OnBeforeUpdateAsync(int id, CityUpdateRequest request, City entity)
        {
            await EnsureRegionExistsAsync(request.RegionId);

            if (await _dbContext.Cities.AnyAsync(c => c.RegionId == request.RegionId && c.Name == request.Name && c.Id != id))
            {
                throw new ConflictException($"A city named '{request.Name}' already exists in this region.");
            }
        }

        protected override async Task OnBeforeDeleteAsync(City entity)
        {
            int destinationCount = await _dbContext.Destinations.CountAsync(d => d.CityId == entity.Id);
            if (destinationCount > 0)
            {
                throw new ConflictException(
                    $"Cannot delete city '{entity.Name}': it is referenced by {destinationCount} destination(s).");
            }
        }

        private async Task EnsureRegionExistsAsync(int regionId)
        {
            if (!await _dbContext.Regions.AnyAsync(r => r.Id == regionId))
            {
                throw new BusinessRuleException($"Region with id {regionId} does not exist.");
            }
        }
    }
}
