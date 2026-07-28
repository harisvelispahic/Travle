using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Services.Database;
using FluentValidation;
using MapsterMapper;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace Travle.Services.BookingStateMachine
{
    /// <summary>
    /// The synthetic pre-state that creates a booking (there is no prior booking to dispatch on, so the
    /// service routes creation here — mirroring the template's Initial state holding Insert). Enforces the
    /// server-side preconditions (slot bookable, tour active, no duplicate/overlap), computes the total
    /// from the tour price, claims capacity with the transactional conditional guard (03 §6) and enters
    /// the booking as PaymentInProgress holding the seats for 15 minutes.
    /// </summary>
    public class InitialBookingState : BaseBookingState
    {
        /// <summary>How long a PaymentInProgress booking holds capacity before the scheduler expires it (spec §3.2).</summary>
        public static readonly TimeSpan HoldDuration = TimeSpan.FromMinutes(15);

        // SQL Server error numbers for a unique-constraint / unique-index violation.
        private const int UniqueViolation = 2627;
        private const int DuplicateKey = 2601;

        private readonly IValidator<BookingInsertRequest> _validator;

        public InitialBookingState(
            TravleDbContext dbContext,
            IMapper mapper,
            IServiceProvider serviceProvider,
            IValidator<BookingInsertRequest> validator)
            : base(dbContext, mapper, serviceProvider)
        {
            _validator = validator;
        }

        public override async Task<BookingResponse> CreateAsync(BookingInsertRequest request, int userId)
        {
            await _validator.ValidateAndThrowAsync(request);

            var slot = await DbContext.TourSchedules
                .Include(s => s.Tour)
                .FirstOrDefaultAsync(s => s.Id == request.TourScheduleId)
                ?? throw new NotFoundException("TourSchedule", request.TourScheduleId);

            var now = DateTime.UtcNow;
            if (slot.Status != ScheduleStatus.Active || slot.StartsAt <= now)
            {
                throw new BusinessRuleException("This schedule is not open for booking.");
            }
            if (!slot.Tour.IsActive)
            {
                throw new BusinessRuleException("This tour is no longer active.");
            }

            // A suspended organizer can't confirm bookings, so their tours are not bookable while suspended
            // (defense in depth — the tour is already hidden from browse). Reverses on unsuspend.
            var organizerSuspended = await DbContext.Users
                .Where(u => u.Id == slot.Tour.OrganizerId)
                .Select(u => u.IsSuspended)
                .FirstOrDefaultAsync();
            if (organizerSuspended)
            {
                throw new BusinessRuleException("This tour is not currently available for booking.");
            }

            // Friendly pre-checks; the filtered unique index and the conditional capacity UPDATE below are
            // the real race backstops (a concurrent request can still slip between check and insert).
            var alreadyActive = await DbContext.Bookings.AnyAsync(b =>
                b.UserId == userId
                && b.TourScheduleId == slot.Id
                && (b.StatusId == (int)BookingStatusCode.PaymentInProgress
                    || b.StatusId == (int)BookingStatusCode.Pending
                    || b.StatusId == (int)BookingStatusCode.Confirmed));
            if (alreadyActive)
            {
                throw new ConflictException("You already have an active booking for this schedule.");
            }

            var overlaps = await DbContext.Bookings.AnyAsync(b =>
                b.UserId == userId
                && b.TourScheduleId != slot.Id
                && (b.StatusId == (int)BookingStatusCode.PaymentInProgress
                    || b.StatusId == (int)BookingStatusCode.Pending
                    || b.StatusId == (int)BookingStatusCode.Confirmed)
                && b.TourSchedule.StartsAt < slot.EndsAt
                && b.TourSchedule.EndsAt > slot.StartsAt);
            if (overlaps)
            {
                throw new BusinessRuleException("You already have a booking that overlaps this time slot.");
            }

            var people = request.NumberOfPeople;
            var totalAmount = slot.Tour.PricePerPerson * people;

            return await InTransactionAsync(async () =>
            {
                // Conditional capacity guard: the row is updated only if seats still remain, atomically —
                // 0 rows affected means the slot filled up under a concurrent booking.
                var claimed = await DbContext.TourSchedules
                    .Where(s => s.Id == slot.Id
                                && s.Status == ScheduleStatus.Active
                                && s.SeatsTaken + people <= s.Capacity)
                    .ExecuteUpdateAsync(set => set.SetProperty(s => s.SeatsTaken, s => s.SeatsTaken + people));

                if (claimed == 0)
                {
                    throw new ConflictException("Not enough free seats remain on this schedule.");
                }

                var booking = new Booking
                {
                    UserId = userId,
                    TourScheduleId = slot.Id,
                    NumberOfPeople = people,
                    TotalAmount = totalAmount,
                    StatusId = (int)BookingStatusCode.PaymentInProgress,
                    StatusChangedAt = now,
                    ExpiresAt = now.Add(HoldDuration)
                };

                DbContext.Bookings.Add(booking);

                try
                {
                    await DbContext.SaveChangesAsync();
                }
                catch (DbUpdateException ex) when (IsUniqueViolation(ex))
                {
                    // Lost the race on the filtered unique index (UserId, TourScheduleId): another
                    // concurrent active booking won. Rolls back with the seat claim (transaction disposes).
                    throw new ConflictException("You already have an active booking for this schedule.");
                }

                return await BuildResponseAsync(booking.Id);
            });
        }

        private static bool IsUniqueViolation(DbUpdateException ex)
            => ex.InnerException is SqlException sql
               && (sql.Number == UniqueViolation || sql.Number == DuplicateKey);
    }
}
