using Travle.Model.Responses;
using Travle.Services.Database;
using MapsterMapper;

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
            // Pending → Confirmed. Seats stay held; a single status change + notification is one save.
            MarkStatus(booking, BookingStatusCode.Confirmed);
            booking.ConfirmedByUserId = organizerUserId;
            AddNotification(booking.UserId, NotificationType.BookingConfirmed,
                "Booking confirmed",
                "Your booking has been confirmed by the organizer.",
                booking.Id);
            await RecordBookingSignalAsync(booking, InteractionType.BookingConfirmed);
            await DbContext.SaveChangesAsync();
            InvalidateRecommendations(booking.UserId);
            return await BuildResponseAsync(booking.Id);
        }

        public override async Task<BookingResponse> RejectAsync(Booking booking, int organizerUserId, string reason)
            => await InTransactionAsync(async () =>
            {
                // Pending → Cancelled (organizer reject): release the seats, record who/why. The 100% refund
                // is issued by IRefundService after this commits (BookingService.RejectAsync orchestrates).
                await ReleaseSeatsAsync(booking.TourScheduleId, booking.NumberOfPeople);
                MarkStatus(booking, BookingStatusCode.Cancelled);
                booking.CancelledByUserId = organizerUserId;
                booking.RejectionReason = reason;
                AddNotification(booking.UserId, NotificationType.BookingRejected,
                    "Booking rejected",
                    $"Your booking was rejected by the organizer. Reason: {reason}. A full refund will be issued.",
                    booking.Id);
                await DbContext.SaveChangesAsync();
                return await BuildResponseAsync(booking.Id);
            });

        public override Task<BookingResponse> CancelAsync(Booking booking, int cancellingUserId, string? reason)
            => CancelByUserAsync(booking, cancellingUserId, reason);

        public override Task<BookingResponse> CancelForSlotAsync(Booking booking, int organizerUserId, string reason)
            => CancelForSlotInternalAsync(booking, organizerUserId, reason);

        public override List<BookingAction> GetAllowedActions()
            => new() { BookingAction.Confirm, BookingAction.Reject, BookingAction.Cancel };
    }
}
