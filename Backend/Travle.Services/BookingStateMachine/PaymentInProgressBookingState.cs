using Travle.Model.Responses;
using Travle.Services.Database;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;

namespace Travle.Services.BookingStateMachine
{
    /// <summary>
    /// A booking holding seats while payment completes. It can move forward to Pending when the Stripe
    /// webhook confirms payment (Phase 6), or lapse to Expired when the 15-minute hold runs out (or
    /// payment fails) — the latter driven by the lifecycle scheduler.
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

        public override async Task<BookingResponse> ExpireAsync(Booking booking, bool paymentFailed = false)
            => await InTransactionAsync(async () =>
            {
                // The hold lapsed or the payment was declined: release the seats and record the expiry. The
                // message distinguishes the two so a card decline doesn't read as "you ran out of time".
                await ReleaseSeatsAsync(booking.TourScheduleId, booking.NumberOfPeople);
                MarkStatus(booking, BookingStatusCode.Expired);
                AddNotification(booking.UserId, NotificationType.BookingExpired,
                    paymentFailed ? "Payment failed" : "Booking expired",
                    paymentFailed
                        ? "Your payment could not be completed, so the booking was released and the seats freed. You can book again to try a different card."
                        : "Your booking hold expired before payment was completed, and the seats were released.",
                    booking.Id);
                await DbContext.SaveChangesAsync();
                return await BuildResponseAsync(booking.Id);
            });

        public override Task<BookingResponse> CancelForSlotAsync(Booking booking, int organizerUserId, string reason)
            => CancelForSlotInternalAsync(booking, organizerUserId, reason);

        public override List<BookingAction> GetAllowedActions() => new() { BookingAction.Pay };
    }
}
