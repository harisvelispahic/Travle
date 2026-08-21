using Travle.Model.Responses;
using Travle.Services.Database;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;

namespace Travle.Services.BookingStateMachine
{
    /// <summary>
    /// A booking holding seats while payment completes. It can move forward to Pending when the Stripe
    /// webhook confirms payment (Phase 6), or lapse to Expired when the 15-minute hold runs out — the
    /// latter driven by the lifecycle scheduler. A declined card is <b>not</b> a way out of this state:
    /// it fails only that payment attempt, leaving the hold running so another card can be tried.
    /// </summary>
    public class PaymentInProgressBookingState : BaseBookingState
    {
        public PaymentInProgressBookingState(TravleDbContext dbContext, IMapper mapper, IServiceProvider serviceProvider)
            : base(dbContext, mapper, serviceProvider)
        {
        }

        public override async Task<BookingResponse> MarkPaidAsync(Booking booking)
        {
            // PaymentInProgress → Pending. Invoked by the signature-verified Stripe webhook; the held seats
            // carry over and the 15-minute hold no longer applies. Any Payment-row edits the caller made on
            // this same DbContext scope commit in the SaveChanges below.
            MarkStatus(booking, BookingStatusCode.Pending);
            booking.ExpiresAt = null;

            AddNotification(booking.UserId, NotificationType.PaymentSucceeded,
                "Payment received",
                "Your payment succeeded. Your booking is now awaiting the organizer's confirmation.",
                booking.Id);

            // Tell the organizer a paid booking is now waiting for their confirmation or rejection.
            var organizerId = await DbContext.TourSchedules
                .Where(s => s.Id == booking.TourScheduleId)
                .Select(s => s.Tour.OrganizerId)
                .FirstAsync();
            AddNotification(organizerId, NotificationType.BookingPlaced,
                "New booking to confirm",
                "A traveler paid for a booking on one of your tour schedules and is awaiting your confirmation.",
                booking.Id);

            await DbContext.SaveChangesAsync();
            return await BuildResponseAsync(booking.Id);
        }

        public override async Task<BookingResponse> ExpireAsync(Booking booking)
            => await InTransactionAsync(async () =>
            {
                // The 15-minute hold lapsed with no completed payment: release the seats and record the
                // expiry. Only the lifecycle sweep reaches this — a declined card fails the payment attempt
                // and leaves the hold running (PaymentService.HandlePaymentFailedAsync).
                await ReleaseSeatsAsync(booking.TourScheduleId, booking.NumberOfPeople);
                MarkStatus(booking, BookingStatusCode.Expired);
                AddNotification(booking.UserId, NotificationType.BookingExpired,
                    "Booking expired",
                    "Your booking hold expired before payment was completed, and the seats were released.",
                    booking.Id);
                await DbContext.SaveChangesAsync();
                return await BuildResponseAsync(booking.Id);
            });

        public override Task<BookingResponse> CancelForSlotAsync(Booking booking, int organizerUserId, string reason)
            => CancelForSlotInternalAsync(booking, organizerUserId, reason);

        public override List<BookingAction> GetAllowedActions() => new() { BookingAction.Pay };
    }
}
