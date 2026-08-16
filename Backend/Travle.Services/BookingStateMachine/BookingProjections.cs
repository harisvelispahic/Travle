using Travle.Model.Responses;
using Travle.Services.Database;

namespace Travle.Services.BookingStateMachine
{
    /// <summary>
    /// The single Booking → <see cref="BookingResponse"/> projection, shared by the read service (list /
    /// detail) and by every state transition (which returns the updated booking). Runs entirely in SQL
    /// and pulls only the small cover thumbnail — never any full destination image bytes (rule 12). The
    /// instant-dependent bits (<c>AllowedActions</c>, the refund preview) and the thumbnail content type
    /// are applied after materialization by the caller, since they need the state factory / current time.
    /// </summary>
    public static class BookingProjections
    {
        /// <summary>Server thumbnails are always JPEG (the generator guarantees it).</summary>
        public const string ThumbnailContentType = "image/jpeg";

        public static IQueryable<BookingResponse> ProjectToResponse(IQueryable<Booking> query)
            => query.Select(b => new BookingResponse
            {
                Id = b.Id,
                UserId = b.UserId,
                TravelerName = b.User.FirstName + " " + b.User.LastName,
                TravelerUsername = b.User.Username,
                TourScheduleId = b.TourScheduleId,
                ScheduleStartsAt = b.TourSchedule.StartsAt,
                ScheduleEndsAt = b.TourSchedule.EndsAt,
                TourId = b.TourSchedule.TourId,
                TourName = b.TourSchedule.Tour.Name,
                OrganizerId = b.TourSchedule.Tour.OrganizerId,
                OrganizerName = b.TourSchedule.Tour.Organizer.FirstName + " " + b.TourSchedule.Tour.Organizer.LastName,
                NumberOfPeople = b.NumberOfPeople,
                TotalAmount = b.TotalAmount,
                // Per-person on-site entrance fees for the booked tour (informative; not charged by Travle).
                EntranceFeesPerPerson = b.TourSchedule.Tour.TourDestinations
                    .Sum(td => td.Destination.EntranceFee ?? 0m),
                StatusId = b.StatusId,
                Status = b.Status.Name,
                StatusChangedAt = b.StatusChangedAt,
                ConfirmedByUserId = b.ConfirmedByUserId,
                ConfirmedByName = b.ConfirmedByUser != null
                    ? b.ConfirmedByUser.FirstName + " " + b.ConfirmedByUser.LastName
                    : null,
                RejectionReason = b.RejectionReason,
                CancelledByUserId = b.CancelledByUserId,
                CancelledByName = b.CancelledByUser != null
                    ? b.CancelledByUser.FirstName + " " + b.CancelledByUser.LastName
                    : null,
                CancellationReason = b.CancellationReason,
                ExpiresAt = b.ExpiresAt,
                IsPaid = b.Payments.Any(p => p.Status == PaymentStatus.Succeeded),
                // The tour review tied to this booking, if any (BookingId is unique per review, so at most
                // one). A review the author self-removed is treated as absent so the booking can be reviewed
                // again; an active or admin-removed one keeps the slot occupied. CanBeReviewed is derived
                // from this + status + viewer by the read service (which knows the current user).
                ReviewId = b.TourSchedule.Tour.Reviews
                    .Where(r => r.BookingId == b.Id && !(r.IsRemoved && r.RemovedByUserId == b.UserId))
                    .Select(r => (int?)r.Id)
                    .FirstOrDefault(),
                TourThumbnail = b.TourSchedule.Tour.TourDestinations
                    .OrderBy(td => td.SortOrder)
                    .Select(td => td.Destination.Images
                        .OrderBy(i => i.SortOrder)
                        .Select(i => i.ThumbnailData)
                        .FirstOrDefault())
                    .FirstOrDefault(),
                CreatedAt = b.CreatedAt,
                ModifiedAt = b.ModifiedAt
            });

        public static void FinalizeThumbnail(BookingResponse response)
            => response.TourThumbnailContentType =
                response.TourThumbnail is { Length: > 0 } ? ThumbnailContentType : null;
    }
}
