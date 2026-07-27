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
                NumberOfPeople = b.NumberOfPeople,
                TotalAmount = b.TotalAmount,
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
