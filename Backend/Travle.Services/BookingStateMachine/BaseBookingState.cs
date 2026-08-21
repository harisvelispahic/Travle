using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Services.Database;
using Travle.Services.Notifications;
using Travle.Services.Recommender;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace Travle.Services.BookingStateMachine
{
    /// <summary>
    /// Base of the booking state pattern. Declares one virtual per lifecycle transition, each defaulting
    /// to a <see cref="BusinessRuleException"/> ("illegal in the current state"); a concrete state overrides
    /// only the transitions it permits and drives the move forward through <see cref="MarkStatus"/> — so
    /// the state machine lives inside the states, never spread across controllers/services (course §
    /// centralized state machine). The current state is rehydrated per request from the persisted
    /// <see cref="Booking.StatusId"/> via <see cref="GetState"/> (the object outlives the request, so it
    /// can't hold a live in-memory state reference the way the classic GoF context does).
    ///
    /// The discriminator is the type-safe <see cref="BookingStatusCode"/> enum whose values equal the
    /// seeded <see cref="BookingStatus"/> ids — never a class-name string. <see cref="MarkStatus"/> is the
    /// single writer of <see cref="Booking.StatusId"/>; nothing outside this hierarchy assigns it.
    /// </summary>
    public class BaseBookingState
    {
        protected TravleDbContext DbContext { get; }
        protected IMapper Mapper { get; }
        protected IServiceProvider ServiceProvider { get; }

        public BaseBookingState(TravleDbContext dbContext, IMapper mapper, IServiceProvider serviceProvider)
        {
            DbContext = dbContext;
            Mapper = mapper;
            ServiceProvider = serviceProvider;
        }

        // --- factory ---------------------------------------------------------------------------------

        /// <summary>Resolves the state handling a given status (each is a DI-registered scoped service).</summary>
        public BaseBookingState GetState(BookingStatusCode code) => code switch
        {
            BookingStatusCode.PaymentInProgress => ServiceProvider.GetRequiredService<PaymentInProgressBookingState>(),
            BookingStatusCode.Pending => ServiceProvider.GetRequiredService<PendingBookingState>(),
            BookingStatusCode.Confirmed => ServiceProvider.GetRequiredService<ConfirmedBookingState>(),
            BookingStatusCode.Completed => ServiceProvider.GetRequiredService<CompletedBookingState>(),
            BookingStatusCode.Cancelled => ServiceProvider.GetRequiredService<CancelledBookingState>(),
            BookingStatusCode.Expired => ServiceProvider.GetRequiredService<ExpiredBookingState>(),
            _ => throw new BusinessRuleException($"Unknown booking status: {code}.")
        };

        /// <summary>The synthetic pre-state that creates a booking (mirrors the template's Initial state).</summary>
        public InitialBookingState GetInitialState() => ServiceProvider.GetRequiredService<InitialBookingState>();

        // --- transitions (default: illegal) ----------------------------------------------------------

        public virtual Task<BookingResponse> CreateAsync(BookingInsertRequest request, int userId)
            => throw Illegal("created");

        public virtual Task<BookingResponse> MarkPaidAsync(Booking booking)
            => throw Illegal("marked as paid");

        public virtual Task<BookingResponse> ConfirmAsync(Booking booking, int organizerUserId)
            => throw Illegal("confirmed");

        public virtual Task<BookingResponse> RejectAsync(Booking booking, int organizerUserId, string reason)
            => throw Illegal("rejected");

        public virtual Task<BookingResponse> CancelAsync(Booking booking, int cancellingUserId, string? reason)
            => throw Illegal("cancelled");

        public virtual Task<BookingResponse> CancelByOrganizerAsync(Booking booking, int organizerUserId, string reason)
            => throw Illegal("cancelled");

        public virtual Task<BookingResponse> CompleteAsync(Booking booking)
            => throw Illegal("completed");

        public virtual Task<BookingResponse> ExpireAsync(Booking booking)
            => throw Illegal("expired");

        public virtual Task<BookingResponse> CancelForSlotAsync(Booking booking, int organizerUserId, string reason)
            => throw Illegal("cancelled");

        public virtual Task<BookingResponse> CancelForOrganizerSuspensionAsync(Booking booking, int adminUserId)
            => throw Illegal("cancelled");

        /// <summary>The transitions this state currently permits (for UI button gating, rule K).</summary>
        public virtual List<BookingAction> GetAllowedActions() => new();

        /// <summary>Names of the allowed transitions for a status, resolved through the factory.</summary>
        public List<string> ResolveAllowedActionNames(int statusId)
            => GetState((BookingStatusCode)statusId).GetAllowedActions().Select(a => a.ToString()).ToList();

        // --- shared transition bodies (legal from more than one state) -------------------------------

        /// <summary>
        /// User (or admin) cancellation, shared by <see cref="PendingBookingState"/> and
        /// <see cref="ConfirmedBookingState"/>: release the held seats, move to Cancelled with audit, and
        /// notify the organizer their slot freed up. The tiered refund is a payment side-effect issued by
        /// <c>IRefundService</c> after this transition commits (BookingService orchestrates), so Stripe is
        /// never called inside this transaction.
        /// </summary>
        protected async Task<BookingResponse> CancelByUserAsync(Booking booking, int cancellingUserId, string? reason)
            => await InTransactionAsync(async () =>
            {
                await ReleaseSeatsAsync(booking.TourScheduleId, booking.NumberOfPeople);
                MarkStatus(booking, BookingStatusCode.Cancelled);
                booking.CancelledByUserId = cancellingUserId;
                booking.CancellationReason = reason;

                var organizerId = await DbContext.TourSchedules
                    .Where(s => s.Id == booking.TourScheduleId)
                    .Select(s => s.Tour.OrganizerId)
                    .FirstAsync();
                AddNotification(organizerId, NotificationType.BookingCancelled,
                    "Booking cancelled",
                    "A traveler cancelled their booking on one of your tour schedules.",
                    booking.Id);

                // Confirm the cancellation to the traveler too — otherwise a cancellation at the 0% refund
                // tier (which issues no RefundIssued notification) would leave them with no trace at all.
                // In-app only: emailing someone about their own just-taken action is noise.
                AddNotification(booking.UserId, NotificationType.BookingCancelled,
                    "Booking cancelled",
                    "Your booking has been cancelled. Any refund due will be processed to your original payment method.",
                    booking.Id);

                await DbContext.SaveChangesAsync();
                return await BuildResponseAsync(booking.Id);
            });

        /// <summary>
        /// Cancellation forced by the tour organizer's suspension, shared by <see cref="PendingBookingState"/>
        /// and <see cref="ConfirmedBookingState"/> (the paid states): release the held seats (the schedule
        /// itself stays Active, unlike a slot-cancel), move to Cancelled with audit, and tell the traveler
        /// their tour won't run and a full refund is coming. The 100% refund is issued by <c>IRefundService</c>
        /// after the suspension transaction commits (UserService orchestrates), so Stripe is never called
        /// inside this transaction. Reuses <see cref="NotificationType.ScheduleCancelled"/> — from the
        /// traveler's side the outcome is identical (their booked tour is cancelled, fully refunded).
        /// </summary>
        protected async Task<BookingResponse> CancelForOrganizerSuspensionInternalAsync(Booking booking, int adminUserId)
            => await InTransactionAsync(async () =>
            {
                await ReleaseSeatsAsync(booking.TourScheduleId, booking.NumberOfPeople);
                MarkStatus(booking, BookingStatusCode.Cancelled);
                booking.CancelledByUserId = adminUserId;
                booking.CancellationReason = "The tour organizer's account was suspended.";
                AddNotification(booking.UserId, NotificationType.ScheduleCancelled,
                    "Tour cancelled",
                    "A tour you booked has been cancelled because the organizer is no longer available. A full refund will be issued.",
                    booking.Id, alsoEmail: true);

                await DbContext.SaveChangesAsync();
                return await BuildResponseAsync(booking.Id);
            });

        /// <summary>
        /// Organizer slot-cancellation, shared by <see cref="PaymentInProgressBookingState"/>,
        /// <see cref="PendingBookingState"/> and <see cref="ConfirmedBookingState"/>: the whole slot is
        /// being retired by the caller (which zeroes it out), so seats are not decremented here — the
        /// booking just moves to Cancelled with a 100% refund owed (issued by <c>IRefundService</c> once
        /// TourService commits the slot-cancel transaction).
        /// </summary>
        protected async Task<BookingResponse> CancelForSlotInternalAsync(Booking booking, int organizerUserId, string reason)
        {
            MarkStatus(booking, BookingStatusCode.Cancelled);
            booking.CancelledByUserId = organizerUserId;
            booking.CancellationReason = reason;
            AddNotification(booking.UserId, NotificationType.ScheduleCancelled,
                "Schedule cancelled",
                $"A tour schedule you booked was cancelled by the organizer. Reason: {reason}. A full refund will be issued.",
                booking.Id, alsoEmail: true);

            await DbContext.SaveChangesAsync();
            return await BuildResponseAsync(booking.Id);
        }

        // --- helpers shared by all states ------------------------------------------------------------

        /// <summary>The single writer of <see cref="Booking.StatusId"/> — the encapsulated "transition to".</summary>
        protected static void MarkStatus(Booking booking, BookingStatusCode next)
        {
            booking.StatusId = (int)next;
            booking.StatusChangedAt = DateTime.UtcNow;
        }

        /// <summary>Atomically returns seats to a slot (the inverse of the capacity guard).</summary>
        protected async Task ReleaseSeatsAsync(int scheduleId, int people)
            => await DbContext.TourSchedules
                .Where(s => s.Id == scheduleId)
                .ExecuteUpdateAsync(set => set.SetProperty(s => s.SeatsTaken, s => s.SeatsTaken - people));

        /// <summary>
        /// Stages a booking notification through the Phase 9 dispatcher (resolved from the scoped provider,
        /// the same instance the request/worker flushes). The row is left unsaved for the caller's
        /// SaveChanges, so it commits inside the same transaction as the status change; the SignalR push and
        /// any email fire on the post-commit flush. Set <paramref name="alsoEmail"/> for the events the spec
        /// also emails (confirmation, rejection, slot cancellation).
        /// </summary>
        protected void AddNotification(int userId, NotificationType type, string title, string text, int bookingId, bool alsoEmail = false)
            => ServiceProvider.GetRequiredService<INotificationDispatcher>()
                .Enqueue(userId, type, title, text, bookingId, alsoEmail);

        /// <summary>
        /// Records the recommender signal for a booking that reached a strong lifecycle state
        /// (Confirmed ⇒ <see cref="InteractionType.BookingConfirmed"/>, Completed ⇒
        /// <see cref="InteractionType.BookingCompleted"/>): one append-only <see cref="UserInteraction"/>
        /// per destination the booked tour visits, so a multi-stop tour feeds every stop's
        /// category/tags/region into the user profile (04 §2). The weight comes from the single
        /// authoritative <see cref="RecommenderOptions"/> table. Rows are left unsaved so they commit
        /// inside the transition's own <c>SaveChangesAsync</c> — the signal and the status change are one
        /// atomic write. Each transition happens exactly once per booking (the state machine forbids
        /// re-confirming/re-completing), so no dedup guard is needed.
        /// </summary>
        protected async Task RecordBookingSignalAsync(Booking booking, InteractionType type)
        {
            var weights = ServiceProvider.GetRequiredService<IOptions<RecommenderOptions>>().Value.Weights;
            var weight = type switch
            {
                InteractionType.BookingConfirmed => weights.BookingConfirmed,
                InteractionType.BookingCompleted => weights.BookingCompleted,
                _ => throw new ArgumentOutOfRangeException(nameof(type), type, "Not a booking lifecycle signal.")
            };

            var destinationIds = await DbContext.TourSchedules
                .Where(s => s.Id == booking.TourScheduleId)
                .SelectMany(s => s.Tour.TourDestinations.Select(td => td.DestinationId))
                .ToListAsync();

            foreach (var destinationId in destinationIds)
            {
                DbContext.UserInteractions.Add(new UserInteraction
                {
                    UserId = booking.UserId,
                    DestinationId = destinationId,
                    InteractionType = type,
                    Weight = weight
                });
            }
        }

        /// <summary>
        /// Drops the user's cached recommendations after a strong booking signal (04 §4). The cache is a
        /// singleton resolved from the provider, so no concrete state's constructor needs to change.
        /// </summary>
        protected void InvalidateRecommendations(int userId)
            => ServiceProvider.GetRequiredService<IRecommendationCache>().InvalidateUser(userId);

        /// <summary>
        /// Runs <paramref name="action"/> inside a DB transaction, enlisting in the caller's transaction
        /// if one is already open (so a batch such as slot-cancel commits atomically) and otherwise
        /// opening its own. Used wherever a transition performs more than one write — a seat change plus
        /// the status/notification save (rule 7).
        /// </summary>
        protected async Task<T> InTransactionAsync<T>(Func<Task<T>> action)
        {
            if (DbContext.Database.CurrentTransaction is not null)
            {
                return await action();
            }

            await using var transaction = await DbContext.Database.BeginTransactionAsync();
            var result = await action();
            await transaction.CommitAsync();
            return result;
        }

        /// <summary>Re-reads the just-mutated booking fully hydrated so the transition returns a complete DTO.</summary>
        protected async Task<BookingResponse> BuildResponseAsync(int bookingId)
        {
            var response = await BookingProjections
                .ProjectToResponse(DbContext.Bookings.AsNoTracking().Where(b => b.Id == bookingId))
                .FirstOrDefaultAsync()
                ?? throw new NotFoundException("Booking", bookingId);

            BookingProjections.FinalizeThumbnail(response);
            response.AllowedActions = ResolveAllowedActionNames(response.StatusId);
            return response;
        }

        private static BusinessRuleException Illegal(string pastTenseAction)
            => new($"This booking cannot be {pastTenseAction} in its current state.");
    }
}
