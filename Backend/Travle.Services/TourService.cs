using Travle.Model.Constants;
using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Authorization;
using Travle.Services.Database;
using Travle.Services.Payments;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace Travle.Services
{
    /// <summary>
    /// Tours domain service. A genuine CRUD entity (organizers create/edit/deactivate their own tours),
    /// so it extends <see cref="BaseCRUDService{TEntity,TResponse,TSearch,TInsertRequest,TUpdateRequest}"/>
    /// for the standard contract, but the verbs are overridden because their default bodies can't express
    /// JWT-owner assignment, the ordered-itinerary reconciliation, or the approved-destinations rule.
    /// Every read is a hand-written projection so the heavy full-image bytes of the visited destinations
    /// are never loaded — only small thumbnails travel (§8.2 / rule 12). Schedule slots hang off a tour
    /// and are managed here too (add / cancel-stub / delete-if-empty); the transactional seat guard that
    /// consumes these slots arrives with bookings in Phase 5.
    /// </summary>
    public class TourService
        : BaseCRUDService<Tour, TourResponse, TourSearch, TourInsertRequest, TourUpdateRequest>,
          ITourService
    {
        private const string ThumbnailContentType = "image/jpeg";

        /// <summary>Upper bound on the upcoming slots embedded in a tour detail (the full history is paged).</summary>
        private const int UpcomingScheduleLimit = 50;

        private readonly IAppAuthorizationService _authorization;
        private readonly IAuthenticatedUserAccessor _currentUser;
        private readonly IBookingService _bookingService;
        private readonly IRefundService _refunds;
        private readonly IValidator<TourScheduleInsertRequest> _scheduleInsertValidator;
        private readonly IValidator<TourScheduleCancelRequest> _scheduleCancelValidator;

        public TourService(
            TravleDbContext dbContext,
            MapsterMapper.IMapper mapper,
            IAppAuthorizationService authorization,
            IAuthenticatedUserAccessor currentUser,
            IBookingService bookingService,
            IRefundService refunds,
            IValidator<TourInsertRequest> insertValidator,
            IValidator<TourUpdateRequest> updateValidator,
            IValidator<TourScheduleInsertRequest> scheduleInsertValidator,
            IValidator<TourScheduleCancelRequest> scheduleCancelValidator)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
            _authorization = authorization;
            _currentUser = currentUser;
            _bookingService = bookingService;
            _refunds = refunds;
            _scheduleInsertValidator = scheduleInsertValidator;
            _scheduleCancelValidator = scheduleCancelValidator;
        }

        // --- reads -------------------------------------------------------------------------------

        protected override IQueryable<Tour> ApplyFilters(IQueryable<Tour> query, TourSearch? search)
        {
            if (search is null)
            {
                return query;
            }

            if (!string.IsNullOrWhiteSpace(search.Text))
            {
                var text = search.Text;
                // Asymmetric accent handling driven by the term (see SearchCollation): plain terms match
                // accent-insensitively; an accented term stays accent-sensitive. Literal collation per branch.
                query = SearchCollation.HasDiacritics(text)
                    ? query.Where(t =>
                        EF.Functions.Collate(t.Name, SearchCollation.CaseInsensitiveAccentSensitive).Contains(text)
                        || EF.Functions.Collate(t.Description, SearchCollation.CaseInsensitiveAccentSensitive).Contains(text))
                    : query.Where(t =>
                        EF.Functions.Collate(t.Name, SearchCollation.CaseInsensitiveAccentInsensitive).Contains(text)
                        || EF.Functions.Collate(t.Description, SearchCollation.CaseInsensitiveAccentInsensitive).Contains(text));
            }

            if (search.TourTypeId.HasValue)
            {
                query = query.Where(t => t.TourTypeId == search.TourTypeId.Value);
            }

            if (search.OrganizerId.HasValue)
            {
                query = query.Where(t => t.OrganizerId == search.OrganizerId.Value);
            }

            if (search.DestinationId.HasValue)
            {
                query = query.Where(t => t.TourDestinations.Any(td => td.DestinationId == search.DestinationId.Value));
            }

            if (search.IsActive.HasValue)
            {
                query = query.Where(t => t.IsActive == search.IsActive.Value);
            }

            if (search.MinPrice.HasValue)
            {
                query = query.Where(t => t.PricePerPerson >= search.MinPrice.Value);
            }

            if (search.MaxPrice.HasValue)
            {
                query = query.Where(t => t.PricePerPerson <= search.MaxPrice.Value);
            }

            if (search.OnlyWithUpcomingSchedules == true)
            {
                var now = DateTime.UtcNow;
                query = query.Where(t => t.Schedules.Any(s => s.Status == ScheduleStatus.Active && s.StartsAt > now));
            }

            return query;
        }

        // Every read goes through a projection (never Mapster / Include) so no full ImageData is loaded.
        public override async Task<PageResult<TourResponse>> GetAllAsync(TourSearch? search = null)
        {
            var now = DateTime.UtcNow;

            IQueryable<Tour> query = _dbContext.Tours.AsNoTracking();
            query = ApplyFilters(query, search);

            int? totalCount = null;
            if (search?.IncludeTotalCount ?? false)
            {
                totalCount = await query.CountAsync();
            }

            query = ApplySorting(query, search);
            query = ApplyPaging(query, search);

            var items = await ProjectToListResponse(query, now).ToListAsync();
            FinalizeThumbnails(items);

            return new PageResult<TourResponse> { Items = items, TotalCount = totalCount };
        }

        public override Task<TourResponse> GetByIdAsync(int id) => GetDetailAsync(id);

        public async Task<PageResult<TourResponse>> SearchAsync(TourSearch? search)
        {
            search ??= new TourSearch();
            // Public browse is active-only; a caller can never widen it to inactive tours or scope it to
            // another organizer.
            search.IsActive = true;
            search.OrganizerId = null;
            search.SortBy ??= "CreatedAt desc";
            return await GetAllAsync(search);
        }

        public async Task<PageResult<TourResponse>> GetMineAsync(TourSearch? search)
        {
            var userId = _authorization.RequireUserId();
            _authorization.EnsureInRole(RoleNames.Organizer);
            search ??= new TourSearch();
            // Force ownership scoping: a caller can never widen this to another organizer's tours.
            search.OrganizerId = userId;
            search.SortBy ??= "CreatedAt desc";
            return await GetAllAsync(search);
        }

        public async Task<TourResponse> GetDetailAsync(int id)
        {
            var meta = await _dbContext.Tours
                .AsNoTracking()
                .Where(t => t.Id == id)
                .Select(t => new { t.OrganizerId, t.IsActive })
                .FirstOrDefaultAsync()
                ?? throw new NotFoundException("Tour", id);

            // A deactivated tour's detail is only for its organizer or an admin — travelers never reach it.
            if (!meta.IsActive)
            {
                _authorization.EnsureSelfOrAdmin(meta.OrganizerId, "tour");
            }

            return await BuildDetailAsync(id);
        }

        public async Task<PageResult<TourScheduleResponse>> GetSchedulesAsync(int tourId, TourScheduleSearch? search)
        {
            var meta = await _dbContext.Tours
                .AsNoTracking()
                .Where(t => t.Id == tourId)
                .Select(t => new { t.OrganizerId })
                .FirstOrDefaultAsync()
                ?? throw new NotFoundException("Tour", tourId);

            var now = DateTime.UtcNow;
            var isOwnerOrAdmin = _currentUser.GetUserId() == meta.OrganizerId || _currentUser.IsInRole(RoleNames.Admin);

            IQueryable<TourSchedule> query = _dbContext.TourSchedules.AsNoTracking().Where(s => s.TourId == tourId);

            if (isOwnerOrAdmin)
            {
                if (search?.ActiveOnly == true)
                {
                    query = query.Where(s => s.Status == ScheduleStatus.Active);
                }
                if (search?.FromDate is DateTime from)
                {
                    query = query.Where(s => s.StartsAt >= from);
                }
                if (search?.ToDate is DateTime to)
                {
                    query = query.Where(s => s.StartsAt < to);
                }
                if (search?.HasFreeSeats == true)
                {
                    query = query.Where(s => s.SeatsTaken < s.Capacity);
                }
            }
            else
            {
                // Non-owners only ever see bookable slots — the search filters are ignored for them.
                query = query.Where(s => s.Status == ScheduleStatus.Active && s.StartsAt > now);
            }

            int? totalCount = null;
            if (search?.IncludeTotalCount ?? false)
            {
                totalCount = await query.CountAsync();
            }

            query = query.OrderBy(s => s.StartsAt);
            query = ApplySchedulePaging(query, search);

            var items = await ProjectSchedule(query).ToListAsync();
            FinalizeScheduleFlags(items, now);

            return new PageResult<TourScheduleResponse> { Items = items, TotalCount = totalCount };
        }

        // --- writes ------------------------------------------------------------------------------

        public override async Task<TourResponse> InsertAsync(TourInsertRequest request)
        {
            // Only organizers create tours; the organizer is the JWT user.
            _authorization.EnsureInRole(RoleNames.Organizer);
            var userId = _authorization.RequireUserId();

            await _insertValidator.ValidateAndThrowAsync(request);
            await EnsureTourTypeExistsAsync(request.TourTypeId);
            await EnsureApprovedDestinationsAsync(request.DestinationIds);

            var tour = new Tour
            {
                OrganizerId = userId,
                Name = request.Name.Trim(),
                Description = request.Description.Trim(),
                DurationMinutes = request.DurationMinutes,
                PricePerPerson = request.PricePerPerson,
                Capacity = request.Capacity,
                TourTypeId = request.TourTypeId,
                IsActive = true
            };

            // The request order is the itinerary order (validator guarantees the ids are distinct).
            var sortOrder = 1;
            foreach (var destinationId in request.DestinationIds)
            {
                tour.TourDestinations.Add(new TourDestination { DestinationId = destinationId, SortOrder = sortOrder++ });
            }

            _dbContext.Tours.Add(tour);
            await _dbContext.SaveChangesAsync();

            return await BuildDetailAsync(tour.Id);
        }

        public override async Task<TourResponse> UpdateAsync(int id, TourUpdateRequest request)
        {
            await _updateValidator.ValidateAndThrowAsync(request);

            var tour = await _dbContext.Tours
                .Include(t => t.TourDestinations)
                .FirstOrDefaultAsync(t => t.Id == id)
                ?? throw new NotFoundException("Tour", id);

            _authorization.EnsureSelfOrAdmin(tour.OrganizerId, "tour");
            await EnsureTourTypeExistsAsync(request.TourTypeId);
            await EnsureApprovedDestinationsAsync(request.DestinationIds);

            tour.Name = request.Name.Trim();
            tour.Description = request.Description.Trim();
            tour.DurationMinutes = request.DurationMinutes;
            tour.PricePerPerson = request.PricePerPerson;
            tour.Capacity = request.Capacity;
            tour.TourTypeId = request.TourTypeId;

            ReconcileDestinations(tour, request.DestinationIds);

            // All reconciliation is tracked in one SaveChanges → a single implicit transaction.
            await _dbContext.SaveChangesAsync();

            return await BuildDetailAsync(id);
        }

        public override async Task DeleteAsync(int id)
        {
            var tour = await _dbContext.Tours.FirstOrDefaultAsync(t => t.Id == id)
                ?? throw new NotFoundException("Tour", id);

            _authorization.EnsureSelfOrAdmin(tour.OrganizerId, "tour");

            // Hard delete is only for a tour that was never scheduled (03 §3). Otherwise it is deactivated,
            // so its schedules/bookings/history stay intact.
            var scheduleCount = await _dbContext.TourSchedules.CountAsync(s => s.TourId == id);
            if (scheduleCount > 0)
            {
                throw new ConflictException(
                    "This tour has schedules and cannot be deleted. Deactivate it instead to hide it from travelers while keeping its history.");
            }

            var reviewCount = await _dbContext.TourReviews.CountAsync(r => r.TourId == id);
            if (reviewCount > 0)
            {
                throw new ConflictException($"This tour cannot be deleted: it has {reviewCount} review(s). Deactivate it instead.");
            }

            _dbContext.Tours.Remove(tour); // TourDestinations cascade away
            await _dbContext.SaveChangesAsync();
        }

        public async Task<TourResponse> DeactivateAsync(int id) => await SetActiveAsync(id, false);

        public async Task<TourResponse> ActivateAsync(int id) => await SetActiveAsync(id, true);

        public async Task<TourScheduleResponse> AddScheduleAsync(int tourId, TourScheduleInsertRequest request)
        {
            await _scheduleInsertValidator.ValidateAndThrowAsync(request);

            var tour = await _dbContext.Tours.FirstOrDefaultAsync(t => t.Id == tourId)
                ?? throw new NotFoundException("Tour", tourId);

            _authorization.EnsureSelfOrAdmin(tour.OrganizerId, "tour");

            if (!tour.IsActive)
            {
                throw new BusinessRuleException("Schedules can only be added to an active tour. Reactivate it first.");
            }

            var startsAt = NormalizeToUtc(request.StartsAt);
            if (startsAt <= DateTime.UtcNow)
            {
                throw new BusinessRuleException("A schedule must start in the future.");
            }

            var schedule = new TourSchedule
            {
                TourId = tourId,
                StartsAt = startsAt,
                // End time is derived from the tour's duration — a slot can't contradict the tour (decision locked P4).
                EndsAt = startsAt.AddMinutes(tour.DurationMinutes),
                Capacity = request.Capacity ?? tour.Capacity,
                SeatsTaken = 0,
                Status = ScheduleStatus.Active
            };

            _dbContext.TourSchedules.Add(schedule);
            await _dbContext.SaveChangesAsync();

            return await BuildScheduleResponseAsync(schedule.Id);
        }

        public async Task<TourScheduleResponse> CancelScheduleAsync(int scheduleId, TourScheduleCancelRequest request)
        {
            await _scheduleCancelValidator.ValidateAndThrowAsync(request);

            var schedule = await _dbContext.TourSchedules
                .Include(s => s.Tour)
                .FirstOrDefaultAsync(s => s.Id == scheduleId)
                ?? throw new NotFoundException("TourSchedule", scheduleId);

            _authorization.EnsureSelfOrAdmin(schedule.Tour.OrganizerId, "tour");
            var actingUserId = _authorization.RequireUserId();

            if (schedule.Status == ScheduleStatus.Cancelled)
            {
                throw new BusinessRuleException("This schedule is already cancelled.");
            }
            if (schedule.StartsAt <= DateTime.UtcNow)
            {
                throw new BusinessRuleException("A schedule that has already started cannot be cancelled.");
            }

            var reason = request.Reason.Trim();
            schedule.Status = ScheduleStatus.Cancelled;
            schedule.CancelledReason = reason;
            schedule.CancelledAt = DateTime.UtcNow;

            // Retire the slot and transition every still-active booking on it to Cancelled through the
            // state machine. The schedule status change and all booking transitions commit atomically in
            // one transaction (rule 7). The block scopes the transaction so it is disposed (no longer the
            // context's ambient transaction) before the refund pass below runs its own SaveChanges.
            {
                await using var transaction = await _dbContext.Database.BeginTransactionAsync();
                await _dbContext.SaveChangesAsync();
                await _bookingService.CancelBookingsForScheduleAsync(scheduleId, actingUserId, reason);
                await transaction.CommitAsync();
            }

            // Only now — outside the transaction — issue the 100% refunds (Stripe network calls must never
            // run inside an open DB transaction). Idempotent: re-running skips already-refunded bookings.
            await _refunds.RefundForScheduleCancellationAsync(
                scheduleId, actingUserId, $"Organizer cancelled the schedule: {reason}");

            return await BuildScheduleResponseAsync(scheduleId);
        }

        public async Task DeleteScheduleAsync(int scheduleId)
        {
            var schedule = await _dbContext.TourSchedules
                .Include(s => s.Tour)
                .FirstOrDefaultAsync(s => s.Id == scheduleId)
                ?? throw new NotFoundException("TourSchedule", scheduleId);

            _authorization.EnsureSelfOrAdmin(schedule.Tour.OrganizerId, "tour");

            // Hard delete is only for fixing a mistaken future slot with no bookings (03 §3).
            if (schedule.StartsAt <= DateTime.UtcNow)
            {
                throw new ConflictException("A past or in-progress schedule cannot be deleted. Cancel it instead if needed.");
            }
            if (schedule.Status != ScheduleStatus.Active)
            {
                throw new ConflictException("Only an active schedule can be deleted.");
            }

            var bookingCount = await _dbContext.Bookings.CountAsync(b => b.TourScheduleId == scheduleId);
            if (bookingCount > 0)
            {
                throw new ConflictException($"This schedule cannot be deleted: it has {bookingCount} booking(s). Cancel the schedule instead.");
            }

            _dbContext.TourSchedules.Remove(schedule);
            await _dbContext.SaveChangesAsync();
        }

        // --- helpers -----------------------------------------------------------------------------

        private async Task<TourResponse> SetActiveAsync(int id, bool isActive)
        {
            var tour = await _dbContext.Tours.FirstOrDefaultAsync(t => t.Id == id)
                ?? throw new NotFoundException("Tour", id);

            _authorization.EnsureSelfOrAdmin(tour.OrganizerId, "tour");

            tour.IsActive = isActive;
            await _dbContext.SaveChangesAsync();

            return await BuildDetailAsync(id);
        }

        // Projects to the list/card shape entirely in SQL, pulling only the cover thumbnail (the ordered-
        // first destination's primary thumbnail) plus lightweight counts — never any full ImageData.
        private static IQueryable<TourResponse> ProjectToListResponse(IQueryable<Tour> query, DateTime now)
            => query.Select(t => new TourResponse
            {
                Id = t.Id,
                Name = t.Name,
                Description = t.Description,
                DurationMinutes = t.DurationMinutes,
                PricePerPerson = t.PricePerPerson,
                Capacity = t.Capacity,
                TourTypeId = t.TourTypeId,
                TourTypeName = t.TourType.Name,
                OrganizerId = t.OrganizerId,
                OrganizerName = t.Organizer.FirstName + " " + t.Organizer.LastName,
                IsActive = t.IsActive,
                DestinationCount = t.TourDestinations.Count,
                UpcomingScheduleCount = t.Schedules.Count(s => s.Status == ScheduleStatus.Active && s.StartsAt > now),
                NextDepartureAt = t.Schedules
                    .Where(s => s.Status == ScheduleStatus.Active && s.StartsAt > now)
                    .OrderBy(s => s.StartsAt)
                    .Select(s => (DateTime?)s.StartsAt)
                    .FirstOrDefault(),
                PrimaryThumbnail = t.TourDestinations
                    .OrderBy(td => td.SortOrder)
                    .Select(td => td.Destination.Images
                        .OrderBy(i => i.SortOrder)
                        .Select(i => i.ThumbnailData)
                        .FirstOrDefault())
                    .FirstOrDefault(),
                CreatedAt = t.CreatedAt,
                ModifiedAt = t.ModifiedAt
            });

        private async Task<TourResponse> BuildDetailAsync(int id)
        {
            var now = DateTime.UtcNow;

            var tour = await ProjectToListResponse(_dbContext.Tours.AsNoTracking().Where(t => t.Id == id), now)
                .FirstOrDefaultAsync()
                ?? throw new NotFoundException("Tour", id);
            FinalizeThumbnail(tour);

            tour.Destinations = await _dbContext.TourDestinations
                .AsNoTracking()
                .Where(td => td.TourId == id)
                .OrderBy(td => td.SortOrder)
                .Select(td => new TourDestinationRef
                {
                    DestinationId = td.DestinationId,
                    Name = td.Destination.Name,
                    CityName = td.Destination.City.Name,
                    Latitude = td.Destination.Latitude,
                    Longitude = td.Destination.Longitude,
                    SortOrder = td.SortOrder,
                    Thumbnail = td.Destination.Images
                        .OrderBy(i => i.SortOrder)
                        .Select(i => i.ThumbnailData)
                        .FirstOrDefault()
                })
                .ToListAsync();

            foreach (var stop in tour.Destinations)
            {
                stop.ThumbnailContentType = stop.Thumbnail is { Length: > 0 } ? ThumbnailContentType : null;
            }

            // Detail carries only the upcoming Active slots (bounded) — the organizer's full history is
            // fetched through the paged schedules endpoint instead.
            var slots = await ProjectSchedule(_dbContext.TourSchedules
                    .AsNoTracking()
                    .Where(s => s.TourId == id && s.Status == ScheduleStatus.Active && s.StartsAt > now)
                    .OrderBy(s => s.StartsAt)
                    .Take(UpcomingScheduleLimit))
                .ToListAsync();
            FinalizeScheduleFlags(slots, now);
            tour.Schedules = slots;

            return tour;
        }

        private static IQueryable<TourScheduleResponse> ProjectSchedule(IQueryable<TourSchedule> query)
            => query.Select(s => new TourScheduleResponse
            {
                Id = s.Id,
                TourId = s.TourId,
                StartsAt = s.StartsAt,
                EndsAt = s.EndsAt,
                Capacity = s.Capacity,
                SeatsTaken = s.SeatsTaken,
                FreeSeats = s.Capacity - s.SeatsTaken,
                Status = s.Status.ToString(),
                CancelledReason = s.CancelledReason,
                CancelledAt = s.CancelledAt,
                CreatedAt = s.CreatedAt,
                ModifiedAt = s.ModifiedAt
            });

        private async Task<TourScheduleResponse> BuildScheduleResponseAsync(int scheduleId)
        {
            var now = DateTime.UtcNow;
            var response = await ProjectSchedule(_dbContext.TourSchedules.AsNoTracking().Where(s => s.Id == scheduleId))
                .FirstOrDefaultAsync()
                ?? throw new NotFoundException("TourSchedule", scheduleId);
            FinalizeScheduleFlag(response, now);
            return response;
        }

        // The action flags depend on the current instant, so they are set after materialization rather
        // than projected — the "disabled with the reason shown" UX on the organizer desktop reads them.
        private static void FinalizeScheduleFlags(IEnumerable<TourScheduleResponse> slots, DateTime now)
        {
            foreach (var slot in slots)
            {
                FinalizeScheduleFlag(slot, now);
            }
        }

        private static void FinalizeScheduleFlag(TourScheduleResponse slot, DateTime now)
        {
            var isActive = slot.Status == nameof(ScheduleStatus.Active);
            var isFuture = slot.StartsAt > now;
            slot.IsCancellable = isActive && isFuture;
            slot.IsDeletable = isActive && isFuture && slot.SeatsTaken == 0;
        }

        // Thumbnails are always JPEG (the generator guarantees it), so the content type is a constant set
        // after materialization rather than projected from the stored (original-format) column.
        private static void FinalizeThumbnails(IEnumerable<TourResponse> items)
        {
            foreach (var item in items)
            {
                FinalizeThumbnail(item);
            }
        }

        private static void FinalizeThumbnail(TourResponse item)
            => item.PrimaryThumbnailContentType = item.PrimaryThumbnail is { Length: > 0 } ? ThumbnailContentType : null;

        private static void ReconcileDestinations(Tour tour, List<int> destinationIds)
        {
            // Drop links no longer in the itinerary.
            foreach (var link in tour.TourDestinations.Where(td => !destinationIds.Contains(td.DestinationId)).ToList())
            {
                tour.TourDestinations.Remove(link);
            }

            // Add new stops and re-number every kept stop to its position in the requested order.
            for (var index = 0; index < destinationIds.Count; index++)
            {
                var destinationId = destinationIds[index];
                var existing = tour.TourDestinations.FirstOrDefault(td => td.DestinationId == destinationId);
                if (existing is null)
                {
                    tour.TourDestinations.Add(new TourDestination { DestinationId = destinationId, SortOrder = index + 1 });
                }
                else
                {
                    existing.SortOrder = index + 1;
                }
            }
        }

        private async Task EnsureTourTypeExistsAsync(int tourTypeId)
        {
            if (!await _dbContext.TourTypes.AnyAsync(tt => tt.Id == tourTypeId))
            {
                throw new BusinessRuleException("The selected tour type does not exist.");
            }
        }

        private async Task EnsureApprovedDestinationsAsync(IEnumerable<int> destinationIds)
        {
            var distinctIds = destinationIds.Distinct().ToList();
            var approvedCount = await _dbContext.Destinations
                .CountAsync(d => distinctIds.Contains(d.Id) && d.Status == DestinationStatus.Approved);

            if (approvedCount != distinctIds.Count)
            {
                throw new BusinessRuleException("Every destination on a tour must be an existing, approved destination.");
            }
        }

        // Paging for the schedules sub-list (the base ApplyPaging is typed to the Tour entity).
        private static IQueryable<TourSchedule> ApplySchedulePaging(IQueryable<TourSchedule> query, TourScheduleSearch? search)
        {
            var page = search?.Page is int p && p > 0 ? p : 1;

            var pageSize = search?.PageSize ?? DefaultPageSize;
            if (pageSize < 1)
            {
                pageSize = DefaultPageSize;
            }
            if (pageSize > MaxPageSize)
            {
                pageSize = MaxPageSize;
            }

            return query.Skip((page - 1) * pageSize).Take(pageSize);
        }

        private static DateTime NormalizeToUtc(DateTime value)
            => value.Kind == DateTimeKind.Unspecified
                ? DateTime.SpecifyKind(value, DateTimeKind.Utc)
                : value.ToUniversalTime();
    }
}
