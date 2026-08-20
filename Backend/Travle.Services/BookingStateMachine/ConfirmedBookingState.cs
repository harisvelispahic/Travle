using Travle.Model.Responses;
using Travle.Services.Database;
using MapsterMapper;

namespace Travle.Services.BookingStateMachine
{
    /// <summary>
    /// A confirmed booking. It auto-completes once the schedule has ended (driven by the lifecycle
    /// scheduler), or the traveler may still cancel it (→ Cancelled, tiered refund); the organizer may
    /// call this one booking off (→ Cancelled, 100% refund) or retire the whole slot (→ Cancelled, 100%).
    /// </summary>
    public class ConfirmedBookingState : BaseBookingState
    {
        public ConfirmedBookingState(TravleDbContext dbContext, IMapper mapper, IServiceProvider serviceProvider)
            : base(dbContext, mapper, serviceProvider)
        {
        }

        public override async Task<BookingResponse> CompleteAsync(Booking booking)
        {
            // Confirmed → Completed after the schedule end time. The seats stay consumed (historical).
            MarkStatus(booking, BookingStatusCode.Completed);
            AddNotification(booking.UserId, NotificationType.BookingCompleted,
                "Tour completed",
                "Your tour is complete. Share your experience by leaving a review!",
                booking.Id);
            await RecordBookingSignalAsync(booking, InteractionType.BookingCompleted);
            await DbContext.SaveChangesAsync();
            InvalidateRecommendations(booking.UserId);
            return await BuildResponseAsync(booking.Id);
        }

        public override Task<BookingResponse> CancelAsync(Booking booking, int cancellingUserId, string? reason)
            => CancelByUserAsync(booking, cancellingUserId, reason);

        /// <summary>
        /// Organizer calls off this single booking (Confirmed → Cancelled): release the seats so they can be
        /// resold, record who/why, and tell the traveler with a full refund promised. Unlike a slot-cancel the
        /// schedule itself stays Active — only this party is dropped, hence the seat release here. The 100%
        /// refund is issued by <c>IRefundService</c> after this commits (BookingService orchestrates), so
        /// Stripe is never called inside the transaction.
        /// </summary>
        public override async Task<BookingResponse> CancelByOrganizerAsync(Booking booking, int organizerUserId, string reason)
            => await InTransactionAsync(async () =>
            {
                await ReleaseSeatsAsync(booking.TourScheduleId, booking.NumberOfPeople);
                MarkStatus(booking, BookingStatusCode.Cancelled);
                booking.CancelledByUserId = organizerUserId;
                booking.CancellationReason = reason;
                AddNotification(booking.UserId, NotificationType.BookingCancelled,
                    "Booking cancelled by the organizer",
                    $"The organizer cancelled your confirmed booking. Reason: {reason}. A full refund will be issued.",
                    booking.Id, alsoEmail: true);

                await DbContext.SaveChangesAsync();
                return await BuildResponseAsync(booking.Id);
            });

        public override Task<BookingResponse> CancelForSlotAsync(Booking booking, int organizerUserId, string reason)
            => CancelForSlotInternalAsync(booking, organizerUserId, reason);

        public override Task<BookingResponse> CancelForOrganizerSuspensionAsync(Booking booking, int adminUserId)
            => CancelForOrganizerSuspensionInternalAsync(booking, adminUserId);

        public override List<BookingAction> GetAllowedActions()
            => new() { BookingAction.Cancel, BookingAction.CancelByOrganizer };
    }
}
