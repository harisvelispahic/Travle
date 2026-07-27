using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;

namespace Travle.Services
{
    /// <summary>
    /// Tours: organizers create and manage their own tours and schedule slots; travelers browse active
    /// tours and their upcoming slots. The CRUD verbs carry domain logic — <c>Insert</c>/<c>Update</c>
    /// own the ordered itinerary (approved destinations only) and are organizer-scoped, and <c>Delete</c>
    /// is a hard delete allowed only for a tour that was never scheduled (otherwise the tour is
    /// deactivated). Schedules hang off a tour: add, cancel (status-only stub — the mass refund +
    /// notifications land in Phase 6) and delete-if-empty.
    /// </summary>
    public interface ITourService
        : IBaseCRUDService<TourResponse, TourSearch, TourInsertRequest, TourUpdateRequest>
    {
        /// <summary>Public browse: active tours only, paginated; a text term matches name/description.</summary>
        Task<PageResult<TourResponse>> SearchAsync(TourSearch? search);

        /// <summary>The current organizer's own tours (active or not), paginated.</summary>
        Task<PageResult<TourResponse>> GetMineAsync(TourSearch? search);

        /// <summary>
        /// Detail read: the tour with its ordered stops and upcoming Active schedules (free seats
        /// included). An inactive tour's detail is visible only to its organizer or an admin.
        /// </summary>
        Task<TourResponse> GetDetailAsync(int id);

        /// <summary>Organizer/admin deactivates a tour (hidden from browsing and new bookings; history kept).</summary>
        Task<TourResponse> DeactivateAsync(int id);

        /// <summary>Organizer/admin reactivates a previously deactivated tour.</summary>
        Task<TourResponse> ActivateAsync(int id);

        /// <summary>
        /// A tour's schedule slots, paginated. Non-owners are narrowed to Active, future slots; the
        /// owner/admin may review past or cancelled slots via the search filters.
        /// </summary>
        Task<PageResult<TourScheduleResponse>> GetSchedulesAsync(int tourId, TourScheduleSearch? search);

        /// <summary>Organizer adds a future slot; the end is derived from the tour's duration.</summary>
        Task<TourScheduleResponse> AddScheduleAsync(int tourId, TourScheduleInsertRequest request);

        /// <summary>
        /// Organizer cancels a slot with a mandatory reason: the slot is retired and every still-active
        /// booking on it is transitioned to Cancelled through the state machine (100% refund owed),
        /// atomically. The refund execution itself lands in Phase 6.
        /// </summary>
        Task<TourScheduleResponse> CancelScheduleAsync(int scheduleId, TourScheduleCancelRequest request);

        /// <summary>Organizer hard-deletes a future, un-booked slot (fixing a mistake). Throws otherwise.</summary>
        Task DeleteScheduleAsync(int scheduleId);
    }
}
