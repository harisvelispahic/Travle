using Travle.Model.Constants;
using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Authorization;
using Travle.Services.BookingStateMachine;
using Travle.Services.Database;
using Travle.Services.Notifications;
using Travle.Services.Payments;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace Travle.Services
{
    /// <summary>
    /// The booking "context": a thin dispatcher over the <c>BookingStateMachine</c>. It loads the booking,
    /// resolves the current state from the persisted <see cref="Booking.StatusId"/> (via the injected
    /// state factory), enforces authorization/ownership, and delegates the actual transition to the state.
    /// Reads are hand-written projections (thumbnails only, rule 12); bookings are never CRUD-updated or
    /// deleted — status is only ever changed by the state machine.
    /// </summary>
    public class BookingService : BaseReadService<Booking, BookingResponse, BookingSearch>, IBookingService
    {
        private readonly IAppAuthorizationService _authorization;
        private readonly IAuthenticatedUserAccessor _currentUser;
        private readonly BaseBookingState _states;
        private readonly IRefundService _refunds;
        private readonly INotificationDispatcher _notifications;
        private readonly IValidator<BookingRejectRequest> _rejectValidator;
        private readonly IValidator<BookingCancelRequest> _cancelValidator;

        public BookingService(
            TravleDbContext dbContext,
            MapsterMapper.IMapper mapper,
            IAppAuthorizationService authorization,
            IAuthenticatedUserAccessor currentUser,
            BaseBookingState states,
            IRefundService refunds,
            INotificationDispatcher notifications,
            IValidator<BookingRejectRequest> rejectValidator,
            IValidator<BookingCancelRequest> cancelValidator)
            : base(mapper, dbContext)
        {
            _authorization = authorization;
            _currentUser = currentUser;
            _states = states;
            _refunds = refunds;
            _notifications = notifications;
            _rejectValidator = rejectValidator;
            _cancelValidator = cancelValidator;
        }

        // --- reads -----------------------------------------------------------------------------------

        protected override IQueryable<Booking> ApplyFilters(IQueryable<Booking> query, BookingSearch? search)
        {
            if (search is null)
            {
                return query;
            }

            if (search.StatusId.HasValue)
            {
                query = query.Where(b => b.StatusId == search.StatusId.Value);
            }
            if (search.UserId.HasValue)
            {
                query = query.Where(b => b.UserId == search.UserId.Value);
            }
            if (search.OrganizerId.HasValue)
            {
                query = query.Where(b => b.TourSchedule.Tour.OrganizerId == search.OrganizerId.Value);
            }
            if (search.TourId.HasValue)
            {
                query = query.Where(b => b.TourSchedule.TourId == search.TourId.Value);
            }
            if (search.TourScheduleId.HasValue)
            {
                query = query.Where(b => b.TourScheduleId == search.TourScheduleId.Value);
            }
            if (search.FromDate is DateTime from)
            {
                query = query.Where(b => b.TourSchedule.StartsAt >= from);
            }
            if (search.ToDate is DateTime to)
            {
                query = query.Where(b => b.TourSchedule.StartsAt < to);
            }

            return query;
        }

        /// <summary>Admin-only all-bookings view. Role-scoped callers use <see cref="QueryAsync"/> directly.</summary>
        public override async Task<PageResult<BookingResponse>> GetAllAsync(BookingSearch? search = null)
        {
            _authorization.EnsureInRole(RoleNames.Admin);
            search ??= new BookingSearch();
            // Default: nearest upcoming departure first (most urgent to act on). An explicit SortBy wins.
            return await QueryAsync(search, DefaultManagementOrder(search));
        }

        public async Task<PageResult<BookingResponse>> GetMineAsync(BookingSearch? search)
        {
            var userId = _authorization.RequireUserId();
            search ??= new BookingSearch();
            // Force ownership scoping: a caller can never widen this to another traveler's bookings.
            search.UserId = userId;
            search.OrganizerId = null;
            search.SortBy ??= "CreatedAt desc";
            return await QueryAsync(search);
        }

        public async Task<PageResult<BookingResponse>> GetForMyToursAsync(BookingSearch? search)
        {
            var userId = _authorization.RequireUserId();
            _authorization.EnsureInRole(RoleNames.Organizer);
            search ??= new BookingSearch();
            // Force scoping to the organizer's own tours.
            search.OrganizerId = userId;
            search.UserId = null;
            // Default: nearest upcoming departure first (most urgent to act on). An explicit SortBy wins.
            return await QueryAsync(search, DefaultManagementOrder(search));
        }

        public override async Task<BookingResponse> GetByIdAsync(int id)
        {
            var meta = await _dbContext.Bookings
                .AsNoTracking()
                .Where(b => b.Id == id)
                .Select(b => new { b.UserId, OrganizerId = b.TourSchedule.Tour.OrganizerId })
                .FirstOrDefaultAsync()
                ?? throw new NotFoundException("Booking", id);

            EnsureCanView(meta.UserId, meta.OrganizerId);

            var response = await BookingProjections
                .ProjectToResponse(_dbContext.Bookings.AsNoTracking().Where(b => b.Id == id))
                .FirstOrDefaultAsync()
                ?? throw new NotFoundException("Booking", id);

            BookingProjections.FinalizeThumbnail(response);
            response.AllowedActions = _states.ResolveAllowedActionNames(response.StatusId);
            ApplyReviewFlag(response);
            await ApplyCancellationRefundPreviewAsync(response);
            return response;
        }

        // --- transitions (dispatch to the state machine) ---------------------------------------------

        public async Task<BookingResponse> CreateAsync(BookingInsertRequest request)
        {
            var userId = _authorization.RequireUserId();
            return await _states.GetInitialState().CreateAsync(request, userId);
        }

        public async Task<BookingResponse> ConfirmAsync(int id)
        {
            var organizerId = _authorization.RequireUserId();
            _authorization.EnsureInRole(RoleNames.Organizer);

            var booking = await LoadForTransitionAsync(id);
            await EnsureOrganizerOwnsBookingTourAsync(id, organizerId);

            var state = _states.GetState((BookingStatusCode)booking.StatusId);
            return await state.ConfirmAsync(booking, organizerId);
        }

        public async Task<BookingResponse> RejectAsync(int id, BookingRejectRequest request)
        {
            var organizerId = _authorization.RequireUserId();
            _authorization.EnsureInRole(RoleNames.Organizer);
            await _rejectValidator.ValidateAndThrowAsync(request);

            var booking = await LoadForTransitionAsync(id);
            await EnsureOrganizerOwnsBookingTourAsync(id, organizerId);

            var reason = request.Reason.Trim();
            var state = _states.GetState((BookingStatusCode)booking.StatusId);
            var response = await state.RejectAsync(booking, organizerId, reason);

            // Organizer rejection ⇒ 100% refund. Issued after the Cancelled transition has committed, so the
            // Stripe call never runs inside a DB transaction (idempotent — a retry won't double-refund).
            await _refunds.RefundForBookingAsync(id, organizerId, $"Organizer rejected the booking: {reason}", forcedPercentage: 100);
            return response;
        }

        public async Task<BookingResponse> CancelAsync(int id, BookingCancelRequest request)
        {
            var userId = _authorization.RequireUserId();
            await _cancelValidator.ValidateAndThrowAsync(request);

            var booking = await LoadForTransitionAsync(id);
            // Only the booking's traveler (or an admin) may cancel it.
            _authorization.EnsureSelfOrAdmin(booking.UserId, "booking");

            var state = _states.GetState((BookingStatusCode)booking.StatusId);
            var response = await state.CancelAsync(booking, userId, request.Reason?.Trim());

            // Traveler cancellation ⇒ tiered refund (null lets the tier resolve from hours-before-start).
            // Post-commit, so the Stripe refund runs outside the cancellation's transaction.
            var refundReason = string.IsNullOrWhiteSpace(request.Reason)
                ? "Traveler cancelled the booking."
                : request.Reason.Trim();
            await _refunds.RefundForBookingAsync(id, userId, refundReason, forcedPercentage: null);
            return response;
        }

        public async Task CancelBookingsForScheduleAsync(int scheduleId, int organizerUserId, string reason)
        {
            var activeIds = await _dbContext.Bookings
                .AsNoTracking()
                .Where(b => b.TourScheduleId == scheduleId
                            && (b.StatusId == (int)BookingStatusCode.PaymentInProgress
                                || b.StatusId == (int)BookingStatusCode.Pending
                                || b.StatusId == (int)BookingStatusCode.Confirmed))
                .Select(b => b.Id)
                .ToListAsync();

            foreach (var id in activeIds)
            {
                var booking = await _dbContext.Bookings.FirstOrDefaultAsync(b => b.Id == id);
                if (booking is null)
                {
                    continue;
                }

                var state = _states.GetState((BookingStatusCode)booking.StatusId);
                await state.CancelForSlotAsync(booking, organizerUserId, reason);
            }
        }

        // --- scheduler maintenance -------------------------------------------------------------------

        public async Task<int> ExpireOverdueHoldsAsync(CancellationToken cancellationToken = default)
        {
            var now = DateTime.UtcNow;
            var dueIds = await _dbContext.Bookings
                .AsNoTracking()
                .Where(b => b.StatusId == (int)BookingStatusCode.PaymentInProgress
                            && b.ExpiresAt != null
                            && b.ExpiresAt <= now)
                .Select(b => b.Id)
                .ToListAsync(cancellationToken);

            var expired = 0;
            foreach (var id in dueIds)
            {
                var booking = await _dbContext.Bookings.FirstOrDefaultAsync(b => b.Id == id, cancellationToken);
                // Re-check under the fresh load: a webhook may have moved it to Pending in the meantime.
                if (booking is null || booking.StatusId != (int)BookingStatusCode.PaymentInProgress)
                {
                    continue;
                }

                await _states.GetState(BookingStatusCode.PaymentInProgress).ExpireAsync(booking);
                expired++;
            }

            return expired;
        }

        public async Task<int> AutoCompletePastConfirmedAsync(CancellationToken cancellationToken = default)
        {
            var now = DateTime.UtcNow;
            var dueIds = await _dbContext.Bookings
                .AsNoTracking()
                .Where(b => b.StatusId == (int)BookingStatusCode.Confirmed
                            && b.TourSchedule.EndsAt <= now)
                .Select(b => b.Id)
                .ToListAsync(cancellationToken);

            var completed = 0;
            foreach (var id in dueIds)
            {
                var booking = await _dbContext.Bookings.FirstOrDefaultAsync(b => b.Id == id, cancellationToken);
                if (booking is null || booking.StatusId != (int)BookingStatusCode.Confirmed)
                {
                    continue;
                }

                await _states.GetState(BookingStatusCode.Confirmed).CompleteAsync(booking);
                completed++;
            }

            return completed;
        }

        public async Task<int> SendDueRemindersAsync(int windowHours, CancellationToken cancellationToken = default)
        {
            var now = DateTime.UtcNow;
            var windowEnd = now.AddHours(windowHours);

            // Confirmed bookings whose schedule starts within the reminder window and that haven't been
            // reminded yet. The "already reminded" guard is a NOT EXISTS against the notification rows
            // themselves (a correlated subquery, so no N+1) — no extra column, and it survives restarts.
            var due = await _dbContext.Bookings
                .AsNoTracking()
                .Where(b => b.StatusId == (int)BookingStatusCode.Confirmed
                            && b.TourSchedule.StartsAt > now
                            && b.TourSchedule.StartsAt <= windowEnd
                            && !_dbContext.Notifications.Any(n =>
                                n.Type == NotificationType.BookingReminder && n.RelatedEntityId == b.Id))
                .Select(b => new
                {
                    b.Id,
                    b.UserId,
                    TourName = b.TourSchedule.Tour.Name,
                    b.TourSchedule.StartsAt
                })
                .ToListAsync(cancellationToken);

            foreach (var booking in due)
            {
                _notifications.Enqueue(booking.UserId, NotificationType.BookingReminder,
                    "Upcoming tour reminder",
                    $"Reminder: your tour '{booking.TourName}' starts on {booking.StartsAt:dd MMM yyyy HH:mm} UTC. We look forward to seeing you!",
                    booking.Id, alsoEmail: true);
            }

            if (due.Count > 0)
            {
                await _dbContext.SaveChangesAsync(cancellationToken);
            }

            return due.Count;
        }

        // --- helpers ---------------------------------------------------------------------------------

        // The management lists (admin + organizer) default to "nearest upcoming departure first" so the
        // most time-critical bookings surface at the top; a client-supplied SortBy still overrides it.
        private static Func<IQueryable<Booking>, IOrderedQueryable<Booking>>? DefaultManagementOrder(BookingSearch search)
            => string.IsNullOrWhiteSpace(search.SortBy) ? OrderByNearestUpcoming : null;

        // Upcoming departures first, soonest at the very top (the urgent ones to confirm/reject before they
        // run); past departures fall below, most recent first. Fully DB-side (translates to ORDER BY CASE …).
        private static IOrderedQueryable<Booking> OrderByNearestUpcoming(IQueryable<Booking> query)
        {
            var now = DateTime.UtcNow;
            return query
                // Upcoming (StartsAt >= now) sorts before past.
                .OrderBy(b => b.TourSchedule.StartsAt >= now ? 0 : 1)
                // Within upcoming: soonest first. Past rows collapse to `now` here so they tie …
                .ThenBy(b => b.TourSchedule.StartsAt >= now ? b.TourSchedule.StartsAt : now)
                // … and are ordered most-recent-first by this final key.
                .ThenByDescending(b => b.TourSchedule.StartsAt);
        }

        // Shared read pipeline (no authorization — callers scope or gate first). When <paramref name="orderBy"/>
        // is supplied it takes precedence over the string-based SortBy (used for the management default order).
        private async Task<PageResult<BookingResponse>> QueryAsync(
            BookingSearch search,
            Func<IQueryable<Booking>, IOrderedQueryable<Booking>>? orderBy = null)
        {
            IQueryable<Booking> query = _dbContext.Bookings.AsNoTracking();
            query = ApplyFilters(query, search);

            int? totalCount = null;
            if (search.IncludeTotalCount ?? false)
            {
                totalCount = await query.CountAsync();
            }

            query = orderBy is not null ? orderBy(query) : ApplySorting(query, search);
            query = ApplyPaging(query, search);

            var items = await BookingProjections.ProjectToResponse(query).ToListAsync();
            foreach (var item in items)
            {
                BookingProjections.FinalizeThumbnail(item);
                item.AllowedActions = _states.ResolveAllowedActionNames(item.StatusId);
                ApplyReviewFlag(item);
            }

            return new PageResult<BookingResponse> { Items = items, TotalCount = totalCount };
        }

        private async Task<Booking> LoadForTransitionAsync(int id)
            => await _dbContext.Bookings.FirstOrDefaultAsync(b => b.Id == id)
               ?? throw new NotFoundException("Booking", id);

        private void EnsureCanView(int ownerUserId, int organizerId)
        {
            var callerId = _authorization.RequireUserId();
            if (callerId == ownerUserId || _currentUser.IsInRole(RoleNames.Admin))
            {
                return;
            }
            if (callerId == organizerId && _currentUser.IsInRole(RoleNames.Organizer))
            {
                return;
            }

            throw new ForbiddenException("You do not have permission to view this booking.");
        }

        private async Task EnsureOrganizerOwnsBookingTourAsync(int bookingId, int organizerId)
        {
            var ownerOrganizerId = await _dbContext.Bookings
                .Where(b => b.Id == bookingId)
                .Select(b => b.TourSchedule.Tour.OrganizerId)
                .FirstAsync();

            if (ownerOrganizerId != organizerId && !_currentUser.IsInRole(RoleNames.Admin))
            {
                throw new ForbiddenException("You can only manage bookings on your own tours.");
            }
        }

        // The "Leave a review" affordance: only for the booking's own traveler, only once it is Completed,
        // and only while it has no review yet (ReviewId is projected including soft-removed rows, so a
        // removed review still blocks a re-review — 03 §3). Everyone else (organizer/admin viewing) sees false.
        private void ApplyReviewFlag(BookingResponse response)
            => response.CanBeReviewed = response.StatusId == (int)BookingStatusCode.Completed
                                        && response.ReviewId == null
                                        && _currentUser.GetUserId() == response.UserId;

        // How much the traveler would be refunded if they cancelled this booking right now — resolved
        // from the global RefundPolicyTiers by hours-before-start. Populated only for the caller's own,
        // still-cancellable booking (the refund itself executes in Phase 6).
        private async Task ApplyCancellationRefundPreviewAsync(BookingResponse response)
        {
            var callerId = _currentUser.GetUserId();
            var cancellable = response.StatusId == (int)BookingStatusCode.Pending
                              || response.StatusId == (int)BookingStatusCode.Confirmed;
            if (callerId != response.UserId || !cancellable)
            {
                return;
            }

            // Same resolver the refund execution uses, so the previewed % always equals the charged one.
            response.CancellationRefundPercentage = await PaymentMath.ResolveRefundPercentageAsync(
                _dbContext, response.ScheduleStartsAt, DateTime.UtcNow);
        }
    }
}
