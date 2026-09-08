using Travle.Model.Responses;
using Travle.Services.Database;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;

namespace Travle.Services.BookingStateMachine
{
    /// <summary>
    /// A paid booking awaiting the organizer's decision. The organizer may confirm it (→ Confirmed) or
    /// reject it with a reason (→ Cancelled, 100% refund); the traveler may still cancel it themselves
    /// (→ Cancelled, tiered refund). The organizer may also retire the whole slot.
    /// </summary>
    public class PendingBookingState : BaseBookingState
    {
        public PendingBookingState(TravleDbContext dbContext, IMapper mapper, IServiceProvider serviceProvider)
            : base(dbContext, mapper, serviceProvider)
        {
        }

        public override async Task<BookingResponse> ConfirmAsync(Booking booking, int organizerUserId)
        {
            // The organizer's decision window closes at departure. After that the lifecycle sweep has
            // already resolved the booking (cancelled, fully refunded), and confirming would rewrite the
            // history of a tour that has run.
            await EnsureScheduleNotStartedAsync(booking, "confirmed");

            // Pending → Confirmed. Seats stay held; a single status change + notification is one save.
            MarkStatus(booking, BookingStatusCode.Confirmed);
            booking.ConfirmedByUserId = organizerUserId;
            AddNotification(booking.UserId, NotificationType.BookingConfirmed,
                "Booking confirmed",
                "Your booking has been confirmed by the organizer.",
                booking.Id, alsoEmail: true);
            await RecordBookingSignalAsync(booking, InteractionType.BookingConfirmed);
            await DbContext.SaveChangesAsync();
            InvalidateRecommendations(booking.UserId);
            return await BuildResponseAsync(booking.Id);
        }

        public override async Task<BookingResponse> RejectAsync(Booking booking, int organizerUserId, string reason)
        {
            // Same window as ConfirmAsync — the two halves of one decision close together.
            await EnsureScheduleNotStartedAsync(booking, "rejected");

            return await InTransactionAsync(async () =>
            {
                // Pending → Cancelled (organizer reject): release the seats, record who/why. The 100% refund
                // is issued by IRefundService after this commits (BookingService.RejectAsync orchestrates).
                await ReleaseSeatsAsync(booking.TourScheduleId, booking.NumberOfPeople);
                MarkStatus(booking, BookingStatusCode.Cancelled);
                booking.CancelledByUserId = organizerUserId;
                booking.RejectionReason = reason;
                await SnapshotRefundObligationAsync(booking, CancellationSource.OrganizerReject);
                AddNotification(booking.UserId, NotificationType.BookingRejected,
                    "Booking rejected",
                    $"Your booking was rejected by the organizer. Reason: {reason}. A full refund will be issued.",
                    booking.Id, alsoEmail: true);
                await DbContext.SaveChangesAsync();
                return await BuildResponseAsync(booking.Id);
            });
        }

        public override Task<BookingResponse> CancelAsync(Booking booking, int cancellingUserId, string? reason)
            => CancelByUserAsync(booking, cancellingUserId, reason);

        public override Task<BookingResponse> CancelForSlotAsync(Booking booking, int organizerUserId, string reason)
            => CancelForSlotInternalAsync(booking, organizerUserId, reason);

        public override Task<BookingResponse> CancelForOrganizerSuspensionAsync(Booking booking, int adminUserId)
            => CancelForOrganizerSuspensionInternalAsync(booking, adminUserId);

        /// <summary>
        /// The lifecycle sweep's answer to a booking the organizer never decided on (Pending → Cancelled at
        /// departure, 100% refund owed). Pending is the one state that can otherwise outlive its own tour:
        /// expiry only reaches held payments and auto-completion only reaches confirmed bookings, so without
        /// this a paid booking whose organizer stayed silent would sit Pending for ever. The traveler paid
        /// and was never accepted, so the money goes back in full; the refund is issued by
        /// <c>IRefundService</c> after this commits (BookingService orchestrates).
        /// </summary>
        public override async Task<BookingResponse> CancelUnconfirmedAtStartAsync(Booking booking)
            => await InTransactionAsync(async () =>
            {
                await ReleaseSeatsAsync(booking.TourScheduleId, booking.NumberOfPeople);
                MarkStatus(booking, BookingStatusCode.Cancelled);
                // No CancelledByUserId: nobody performed this cancellation, the clock did.
                booking.CancellationReason = "The organizer did not confirm this booking before the tour started.";
                await SnapshotRefundObligationAsync(booking, CancellationSource.UnconfirmedAtStart);

                AddNotification(booking.UserId, NotificationType.BookingUnconfirmed,
                    "Booking cancelled — never confirmed",
                    "Your booking was cancelled because the organizer did not confirm it before the tour started. "
                    + "A full refund will be issued to your original payment method.",
                    booking.Id, alsoEmail: true);

                var organizerId = await DbContext.TourSchedules
                    .Where(s => s.Id == booking.TourScheduleId)
                    .Select(s => s.Tour.OrganizerId)
                    .FirstAsync();
                // In-app only for the organizer: the traveler's copy is about money coming back and earns an
                // email, while this one reports the consequence of their own inaction — the same reasoning
                // that keeps a traveler's own cancellation in-app (see CancelByUserAsync).
                AddNotification(organizerId, NotificationType.BookingCancelled,
                    "Booking cancelled — you did not confirm it",
                    "A paid booking on one of your tour schedules reached its departure without being confirmed "
                    + "or rejected, so it was cancelled automatically and the traveler refunded in full.",
                    booking.Id);

                await DbContext.SaveChangesAsync();
                return await BuildResponseAsync(booking.Id);
            });

        public override List<BookingAction> GetAllowedActions()
            => new() { BookingAction.Confirm, BookingAction.Reject, BookingAction.Cancel };
    }
}
