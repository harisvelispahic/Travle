using Travle.Model.Responses;
using Travle.Services.Database;
using MapsterMapper;

namespace Travle.Services.BookingStateMachine
{
    /// <summary>
    /// A confirmed booking. It auto-completes once the schedule has ended (driven by the lifecycle
    /// scheduler), or the traveler may still cancel it (→ Cancelled, tiered refund); the organizer may
    /// also retire the whole slot (→ Cancelled, 100% refund).
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

        public override Task<BookingResponse> CancelForSlotAsync(Booking booking, int organizerUserId, string reason)
            => CancelForSlotInternalAsync(booking, organizerUserId, reason);

        public override Task<BookingResponse> CancelForOrganizerSuspensionAsync(Booking booking, int adminUserId)
            => CancelForOrganizerSuspensionInternalAsync(booking, adminUserId);

        public override List<BookingAction> GetAllowedActions() => new() { BookingAction.Cancel };
    }
}
