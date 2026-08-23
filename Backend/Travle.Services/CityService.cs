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

        private static string BlockedReason(string name, int destinationCount, int userCount)
            => $"Cannot delete city '{name}': it is referenced by {destinationCount} destination(s) and "
               + $"{userCount} user profile(s).";

        // Projected list read: usage = destinations in the city + users who call it home.
        public override Task<PageResult<CityResponse>> GetAllAsync(CitySearch? search = null)
            => GetPageAsync(
                search,
                c => new CityResponse
                {
                    Id = c.Id,
                    Name = c.Name,
                    RegionId = c.RegionId,
                    RegionName = c.Region.Name,
                    TimeZoneId = c.TimeZoneId,
                    UsageCount = _dbContext.Destinations.Count(d => d.CityId == c.Id)
                                 + _dbContext.Users.Count(u => u.CityId == c.Id),
                    CreatedAt = c.CreatedAt,
                    ModifiedAt = c.ModifiedAt
                },
                row => row.DeleteBlockedReason = row.UsageCount == 0
                    ? null
                    : $"Cannot delete city '{row.Name}': it is still referenced by "
                      + $"{row.UsageCount} other record(s).");

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
            // Users pick a home city too, and that FK is Restrict — without this check the delete escapes
            // as a raw DbUpdateException (a bare 500) instead of the required human explanation.
            int userCount = await _dbContext.Users.CountAsync(u => u.CityId == entity.Id);

            if (destinationCount > 0 || userCount > 0)
            {
                throw new ConflictException(BlockedReason(entity.Name, destinationCount, userCount));
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
