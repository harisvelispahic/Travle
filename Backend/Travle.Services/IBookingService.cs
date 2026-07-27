using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;

namespace Travle.Services
{
    /// <summary>
    /// Bookings: not a CRUD entity. Creation and every transition run through the centralized
    /// <c>BookingStateMachine</c> (this service is the thin dispatcher / context). Reads are role-scoped:
    /// <see cref="GetMineAsync"/> is the traveler's own history, <see cref="GetForMyToursAsync"/> is an
    /// organizer's bookings across their tours, and the inherited <see cref="IBaseReadService{T,S}.GetAllAsync"/>
    /// is the admin-only all-bookings view. Bookings are never deleted (status machine only).
    /// </summary>
    public interface IBookingService : IBaseReadService<BookingResponse, BookingSearch>
    {
        /// <summary>Traveler checkout: creates the booking as PaymentInProgress with a 15-minute hold.</summary>
        Task<BookingResponse> CreateAsync(BookingInsertRequest request);

        /// <summary>The current traveler's own bookings, newest first, paginated.</summary>
        Task<PageResult<BookingResponse>> GetMineAsync(BookingSearch? search);

        /// <summary>Bookings on the current organizer's tours, newest first, paginated.</summary>
        Task<PageResult<BookingResponse>> GetForMyToursAsync(BookingSearch? search);

        /// <summary>Organizer confirms a pending booking on one of their tours (Pending → Confirmed).</summary>
        Task<BookingResponse> ConfirmAsync(int id);

        /// <summary>Organizer rejects a pending booking with a reason (Pending → Cancelled, 100% refund in P6).</summary>
        Task<BookingResponse> RejectAsync(int id, BookingRejectRequest request);

        /// <summary>Traveler cancels their own booking (Pending/Confirmed → Cancelled, tiered refund in P6).</summary>
        Task<BookingResponse> CancelAsync(int id, BookingCancelRequest request);

        /// <summary>
        /// Transitions every still-active booking on a cancelled slot to Cancelled (100% refund owed).
        /// Called by <c>TourService.CancelScheduleAsync</c> inside the slot-cancel transaction.
        /// </summary>
        Task CancelBookingsForScheduleAsync(int scheduleId, int organizerUserId, string reason);

        /// <summary>Scheduler tick: expire every PaymentInProgress hold past its 15-minute window. Returns the count.</summary>
        Task<int> ExpireOverdueHoldsAsync(CancellationToken cancellationToken = default);

        /// <summary>Scheduler tick: auto-complete every Confirmed booking whose schedule has ended. Returns the count.</summary>
        Task<int> AutoCompletePastConfirmedAsync(CancellationToken cancellationToken = default);
    }
}
